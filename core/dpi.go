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
	fragmentedCount int
	mu              sync.Mutex
}

func (c *fragmentingConn) Write(b []byte) (int, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if len(b) > 1 && c.fragmentedCount < 10 {
		c.fragmentedCount++
		n1, err := c.Conn.Write(b[:1])
		if err != nil {
			return n1, err
		}
		time.Sleep(25 * time.Millisecond)
		n2, err := c.Conn.Write(b[1:])
		return n1 + n2, err
	}
	return c.Conn.Write(b)
}

type dpiEngine struct {
	client *http.Client
}

func newDPIEngine() *dpiEngine {
	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			var dialer net.Dialer
			conn, err := dialer.DialContext(ctx, network, addr)
			if err != nil {
				return nil, err
			}
			if tcpConn, ok := conn.(*net.TCPConn); ok {
				_ = tcpConn.SetNoDelay(true)
			}
			return &fragmentingConn{Conn: conn}, nil
		},
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
		DisableKeepAlives:   false,
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 20,
		IdleConnTimeout:     90 * time.Second,
	}

	return &dpiEngine{
		client: &http.Client{
			Transport: transport,
			Timeout:   30 * time.Second,
		},
	}
}

var defaultHeaders = map[string]string{
	"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Referer":    "https://hitomi.la/",
}

func (d *dpiEngine) Fetch(rawURL string, customHeaders map[string]string) ([]byte, int, http.Header, error) {
	dotURL := rawURL
	if strings.Contains(rawURL, "hitomi.la/") {
		dotURL = strings.Replace(rawURL, "hitomi.la/", "hitomi.la./", 1)
	}

	parsed, err := url.Parse(dotURL)
	if err != nil {
		return nil, 0, nil, fmt.Errorf("invalid url: %w", err)
	}

	hostname := parsed.Hostname()
	modifiedHostname := hostname
	if len(hostname) > 0 {
		lastChar := strings.ToUpper(string(hostname[len(hostname)-1]))
		modifiedHostname = hostname[:len(hostname)-1] + lastChar
	}

	var lastErr error
	for attempt := 1; attempt <= 3; attempt++ {
		req, err := http.NewRequest(http.MethodGet, dotURL, nil)
		if err != nil {
			return nil, 0, nil, err
		}

		padding := strings.Repeat("x", 500)
		for i := 0; i < 21; i++ {
			req.Header.Set(fmt.Sprintf("X-Padding-%d", i), padding)
		}

		for k, v := range defaultHeaders {
			req.Header.Set(k, v)
		}
		for k, v := range customHeaders {
			req.Header.Set(k, v)
		}
		req.Host = modifiedHostname

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

		if resp.StatusCode == 404 || (resp.StatusCode >= 200 && resp.StatusCode < 300) || resp.StatusCode == 206 {
			return body, resp.StatusCode, resp.Header, nil
		}

		if attempt == 3 {
			return body, resp.StatusCode, resp.Header, nil
		}
		time.Sleep(200 * time.Millisecond)
	}

	return nil, 0, nil, fmt.Errorf("fetch failed after 3 attempts: %w", lastErr)
}
