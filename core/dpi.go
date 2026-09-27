package core

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

type fragmentingConn struct {
	net.Conn
	firstWrite sync.Once
}

func (c *fragmentingConn) Write(b []byte) (n int, err error) {
	fragment := false
	c.firstWrite.Do(func() { fragment = true })
	if !fragment || len(b) <= 1 {
		return c.Conn.Write(b)
	}

	// Split only the first TLS write. This preserves the DPI bypass for the
	// ClientHello without adding a delay to every encrypted HTTP write.
	n1, err := c.Conn.Write(b[:1])
	if err != nil {
		return n1, err
	}
	time.Sleep(50 * time.Millisecond)
	n2, err := c.Conn.Write(b[1:])
	return n1 + n2, err
}

type dpiEngine struct {
	client *http.Client
}

func newDPIEngine() *dpiEngine {
	tlsConfig := &tls.Config{
		NextProtos: []string{"h2", "http/1.1"},
	}
	transport := &http.Transport{
		DialTLSContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			var dialer net.Dialer
			conn, err := dialer.DialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			if tcpConn, ok := conn.(*net.TCPConn); ok {
				_ = tcpConn.SetNoDelay(true)
			}

			host, _, err := net.SplitHostPort(addr)
			if err != nil {
				_ = conn.Close()
				return nil, fmt.Errorf("invalid TLS address %q: %w", addr, err)
			}
			config := tlsConfig.Clone()
			// The DNS-dot URL intentionally ends the hostname with a dot. DNS
			// keeps that bypass behavior, while certificate verification uses
			// the canonical hostname expected by the CDN certificate.
			config.ServerName = strings.TrimSuffix(host, ".")
			tlsConn := tls.Client(&fragmentingConn{Conn: conn}, config)
			if err := tlsConn.HandshakeContext(ctx); err != nil {
				_ = tlsConn.Close()
				return nil, err
			}
			return tlsConn, nil
		},
		TLSClientConfig:     tlsConfig,
		ForceAttemptHTTP2:   true,
		MaxIdleConns:        16,
		MaxIdleConnsPerHost: 4,
		IdleConnTimeout:     90 * time.Second,
	}

	return &dpiEngine{
		client: &http.Client{
			Transport: transport,
			Timeout:   15 * time.Second,
		},
	}
}

var defaultHeaders = map[string]string{
	"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Referer":    "https://hitomi.la/",
}

func (d *dpiEngine) Fetch(rawURL string, customHeaders map[string]string) ([]byte, int, http.Header, error) {
	parsedRaw, err := url.Parse(rawURL)
	if err != nil {
		return nil, 0, nil, fmt.Errorf("invalid url: %w", err)
	}

	dotURL := rawURL
	if strings.Contains(rawURL, "hitomi.la/") {
		dotURL = strings.Replace(rawURL, "hitomi.la/", "hitomi.la./", 1)
	}

	hostname := parsedRaw.Hostname()

	var lastErr error
	for attempt := 1; attempt <= 3; attempt++ {
		req, err := http.NewRequest(http.MethodGet, dotURL, nil)
		if err != nil {
			return nil, 0, nil, err
		}

		for k, v := range defaultHeaders {
			req.Header.Set(k, v)
		}
		for k, v := range customHeaders {
			req.Header.Set(k, v)
		}
		req.Host = hostname

		resp, err := d.client.Do(req)
		if err != nil {
			lastErr = err
			if attempt < 3 {
				time.Sleep(200 * time.Millisecond)
			}
			continue
		}

		body, readErr := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		if readErr != nil {
			lastErr = readErr
			if attempt < 3 {
				time.Sleep(200 * time.Millisecond)
			}
			continue
		}

		// 404 is the CDN saying the key rotated; retrying the same URL cannot help.
		if resp.StatusCode == 404 || (resp.StatusCode >= 200 && resp.StatusCode < 300) {
			return body, resp.StatusCode, resp.Header, nil
		}

		if attempt == 3 {
			return body, resp.StatusCode, resp.Header, nil
		}
		time.Sleep(200 * time.Millisecond)
	}

	return nil, 0, nil, fmt.Errorf("fetch failed after 3 attempts: %w", lastErr)
}
