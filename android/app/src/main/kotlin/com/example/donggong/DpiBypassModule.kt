package com.example.donggong

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import okhttp3.*
import java.io.OutputStream
import java.net.InetAddress
import java.net.Socket
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.SocketFactory
import javax.net.ssl.*

class DpiBypassModule : MethodChannel.MethodCallHandler {

    private val client: OkHttpClient by lazy {
        val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        })

        val sslContext = SSLContext.getInstance("SSL")
        sslContext.init(null, trustAllCerts, SecureRandom())

        OkHttpClient.Builder()
            .sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
            .hostnameVerifier { _, _ -> true }
            .socketFactory(FragmentingSocketFactory())
            .dns(object : Dns {
                override fun lookup(hostname: String): List<InetAddress> {
                    val addresses = Dns.SYSTEM.lookup(hostname)
                    val ipv4 = addresses.filter { it is java.net.Inet4Address }
                    if (ipv4.isNotEmpty()) {
                        return ipv4
                    }
                    return addresses
                }
            })
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "fetch") {
            val url = call.argument<String>("url")
            val headersMap = call.argument<Map<String, String>>("headers")

            if (url == null) {
                result.error("INVALID_URL", "URL is null", null)
                return
            }

            Thread {
                var lastException: Exception? = null
                
                try {
                    val dotUrl = if (url.contains("hitomi.la/")) {
                        url.replace("hitomi.la/", "hitomi.la./")
                    } else url

                    val originalUrl = java.net.URL(dotUrl)
                    val hostname = originalUrl.host
                    
                    val modifiedHostname = if (hostname.isNotEmpty()) {
                        hostname.substring(0, hostname.length - 1) + hostname.substring(hostname.length - 1).uppercase()
                    } else hostname

                    val requestBuilder = Request.Builder().url(dotUrl)
                    
                    for (i in 0 until 21) {
                        val padding = "x".repeat(500)
                        requestBuilder.addHeader("X-Padding-$i", padding)
                    }

                    if (headersMap != null) {
                        var hasHostHeader = false
                        for ((key, value) in headersMap) {
                            if (key.lowercase() == "host") {
                                requestBuilder.addHeader("hOSt", modifiedHostname)
                                hasHostHeader = true
                            } else {
                                requestBuilder.addHeader(key, value)
                            }
                        }
                        if (!hasHostHeader) {
                            requestBuilder.addHeader("hOSt", modifiedHostname)
                        }
                    } else {
                        requestBuilder.addHeader("hOSt", modifiedHostname)
                    }

                    for (attempt in 1..3) {
                        try {
                            val callObj = client.newCall(requestBuilder.build())
                            callObj.execute().use { response ->
                                val responseBytes = response.body?.bytes() ?: ByteArray(0)
                                val responseHeaders = response.headers.toMultimap().mapValues { entry ->
                                    entry.value.joinToString(",")
                                }
                                if (response.isSuccessful) {
                                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                                        result.success(mapOf(
                                            "bodyBytes" to responseBytes,
                                            "body" to String(responseBytes, Charsets.UTF_8),
                                            "statusCode" to response.code,
                                            "headers" to responseHeaders
                                        ))
                                    }
                                    return@Thread
                                } else {
                                    // Even for non-successful status codes, if we reached the server, 
                                    // we might want to return the actual status code instead of retrying 3 times?
                                    // Actually, Hitomi sometimes blocks temporarily, so retry is good.
                                    // But if it's 404, we should probably stop.
                                    if (response.code == 404 || attempt == 3) {
                                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                                            result.success(mapOf(
                                                "bodyBytes" to responseBytes,
                                                "body" to String(responseBytes, Charsets.UTF_8),
                                                "statusCode" to response.code,
                                                "headers" to responseHeaders
                                            ))
                                        }
                                        return@Thread
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            lastException = e
                            if (attempt < 3) Thread.sleep(200)
                        }
                    }
                } catch (e: Exception) {
                    lastException = e
                }

                // If we exit loop, it means we caught exceptions 3 times
                val finalEx = lastException
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    result.error("FETCH_ERROR", "All 3 attempts failed: ${finalEx?.message ?: "Unknown error"}", null)
                }
            }.start()
        } else {
            result.notImplemented()
        }
    }

    private class FragmentingSocketFactory : SocketFactory() {
        private val defaultFactory = SocketFactory.getDefault()

        override fun createSocket(): Socket = FragmentingSocket(defaultFactory.createSocket())
        override fun createSocket(host: String?, port: Int): Socket = FragmentingSocket(defaultFactory.createSocket(host, port))
        override fun createSocket(host: String?, port: Int, localHost: InetAddress?, localPort: Int): Socket = FragmentingSocket(defaultFactory.createSocket(host, port, localHost, localPort))
        override fun createSocket(host: InetAddress?, port: Int): Socket = FragmentingSocket(defaultFactory.createSocket(host, port))
        override fun createSocket(address: InetAddress?, port: Int, localAddress: InetAddress?, localPort: Int): Socket = FragmentingSocket(defaultFactory.createSocket(address, port, localAddress, localPort))
    }

    private class FragmentingSocket(private val delegate: Socket) : Socket() {
        init {
            try {
                delegate.tcpNoDelay = true
            } catch (e: Exception) {}
        }

        override fun getOutputStream(): OutputStream {
            return FragmentingOutputStream(delegate.getOutputStream())
        }

        override fun connect(endpoint: java.net.SocketAddress?) = delegate.connect(endpoint)
        override fun connect(endpoint: java.net.SocketAddress?, timeout: Int) = delegate.connect(endpoint, timeout)
        override fun bind(bindpoint: java.net.SocketAddress?) = delegate.bind(bindpoint)
        override fun getInetAddress(): InetAddress = delegate.inetAddress
        override fun getLocalAddress(): InetAddress = delegate.localAddress
        override fun getPort(): Int = delegate.port
        override fun getLocalPort(): Int = delegate.localPort
        override fun getInputStream(): java.io.InputStream = delegate.inputStream
        override fun setKeepAlive(on: Boolean) { delegate.keepAlive = on }
        override fun getKeepAlive(): Boolean = delegate.keepAlive
        override fun close() = delegate.close()
        override fun isConnected(): Boolean = delegate.isConnected
        override fun isClosed(): Boolean = delegate.isClosed
        override fun setSoTimeout(timeout: Int) { delegate.soTimeout = timeout }
        override fun getSoTimeout(): Int = delegate.soTimeout
    }

    private class FragmentingOutputStream(private val delegate: OutputStream) : OutputStream() {
        private var fragmentedCount = 0

        override fun write(b: Int) {
            delegate.write(b)
            delegate.flush()
        }

        override fun write(b: ByteArray) {
            write(b, 0, b.size)
        }

        override fun write(b: ByteArray, off: Int, len: Int) {
            if (len > 0) {
                try {
                    if (fragmentedCount < 10 && len > 1) {
                        fragmentedCount++
                        delegate.write(b[off].toInt())
                        delegate.flush()
                        Thread.sleep(25)
                        delegate.write(b, off + 1, len - 1)
                        delegate.flush()
                    } else {
                        delegate.write(b, off, len)
                        delegate.flush()
                    }
                } catch (e: Exception) {
                    delegate.write(b, off, len)
                    delegate.flush()
                }
            }
        }

        override fun flush() = delegate.flush()
        override fun close() = delegate.close()
    }
}
