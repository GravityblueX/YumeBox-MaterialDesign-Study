/*
 * This file is part of YumeBox.
 *
 * YumeBox is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright (c)  YumeLira 2025 - Present
 *
 */

package com.github.yumelira.yumebox.update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.core.content.FileProvider
import com.github.yumelira.yumebox.BuildConfig
import dev.oom_wg.purejoy.mlang.MLang
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.coroutineContext

class GitHubUpdateManager(
    context: Context,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build(),
) {
    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true }
    private val _downloadProgress = MutableStateFlow(UpdateDownloadProgress())
    @Volatile
    private var activeDownloadCall: Call? = null
    @Volatile
    private var downloadCancelRequested: Boolean = false
    @Volatile
    private var autoCheckJob: Job? = null
    val downloadProgress: StateFlow<UpdateDownloadProgress> = _downloadProgress.asStateFlow()
    private val _cachedCandidate = MutableStateFlow<UpdateCandidate?>(null)
    val cachedCandidate: StateFlow<UpdateCandidate?> = _cachedCandidate.asStateFlow()

    suspend fun checkForUpdate(): Result<UpdateCandidate?> = withContext(Dispatchers.IO) {
        runCatching {
            val manifest = fetchManifest()
            if (manifest.versionCode <= BuildConfig.VERSION_CODE.toLong()) {
                _cachedCandidate.value = null
                return@runCatching null
            }
            val candidate = UpdateCandidate(manifest)
            _cachedCandidate.value = candidate
            candidate
                .withCachedCover()
                .also { _cachedCandidate.value = it }
        }
    }

    fun startAutoCheck(scope: CoroutineScope, intervalMs: Long = AUTO_CHECK_INTERVAL_MS) {
        if (autoCheckJob?.isActive == true) return
        synchronized(this) {
            if (autoCheckJob?.isActive == true) return
            autoCheckJob = scope.launch(Dispatchers.IO) {
                while (isActive) {
                    runCatching {
                        checkForUpdate()
                    }.onFailure { throwable ->
                        if (throwable is CancellationException) throw throwable
                        Timber.w(throwable, "Update auto check failed")
                    }
                    delay(intervalMs)
                }
            }
        }
    }

    suspend fun downloadAndInstall(candidate: UpdateCandidate): Result<Unit> = withContext(Dispatchers.IO) {
        if (_downloadProgress.value.isDownloading) {
            return@withContext Result.failure(IllegalStateException(MLang.Component.Update.Message.DownloadAlreadyRunning))
        }

        val outputFile = File(
            appContext.cacheDir,
            "updates/${candidate.resolveDownloadFileName()}",
        )

        runCatching {
            downloadCancelRequested = false
            _downloadProgress.value = UpdateDownloadProgress(
                isDownloading = true,
                progress = 0,
                message = MLang.Component.Update.Message.Preparing,
            )

            outputFile.parentFile?.mkdirs()
            if (outputFile.exists()) outputFile.delete()

            val downloadUrls = candidate.resolveDownloadUrls()
            val errors = mutableListOf<String>()
            for (url in downloadUrls) {
                if (downloadCancelRequested) throw UpdateDownloadCancelledException()
                coroutineContext.ensureActive()
                val downloaded = runCatching {
                    downloadToFile(url, outputFile)
                    if (downloadCancelRequested) throw UpdateDownloadCancelledException()
                    true
                }.onFailure { throwable ->
                    if (throwable is CancellationException) {
                        throw throwable
                    }
                    if (throwable.isUpdateDownloadCancelled()) {
                        throw throwable
                    }
                    Timber.e(throwable, "Update download failed: $url")
                    errors += throwable.message ?: url
                    if (outputFile.exists()) outputFile.delete()
                }.getOrDefault(false)

                if (downloaded) {
                    _downloadProgress.value = UpdateDownloadProgress(
                        isDownloading = false,
                        progress = 100,
                        message = MLang.Component.Update.Message.DownloadReady,
                    )
                    openInstaller(outputFile)
                    return@runCatching
                }
            }

            error(errors.firstOrNull() ?: MLang.Component.Update.Message.Error)
        }.onFailure { throwable ->
            if (throwable is CancellationException) {
                throw throwable
            }
            _downloadProgress.value = UpdateDownloadProgress(
                isDownloading = false,
                progress = 0,
                message = if (throwable.isUpdateDownloadCancelled()) {
                    MLang.Component.Update.Message.DownloadCancelled
                } else {
                    throwable.message ?: MLang.Component.Update.Message.Error
                },
            )
            if (throwable.isUpdateDownloadCancelled() && outputFile.exists()) {
                outputFile.delete()
            }
        }.also {
            downloadCancelRequested = false
        }
    }

    fun cancelDownload() {
        downloadCancelRequested = true
        activeDownloadCall?.cancel()
        _downloadProgress.value = UpdateDownloadProgress(
            isDownloading = false,
            progress = 0,
            message = MLang.Component.Update.Message.DownloadCancelled,
        )
    }

    private fun UpdateCandidate.withCachedCover(): UpdateCandidate {
        val fallbackCachedUri = cacheCoverDataUri(versionCode, coverDataUri)
        val fallbackCandidate = if (fallbackCachedUri.isBlank()) this else copy(cachedCoverUri = fallbackCachedUri)
        if (fallbackCandidate.cachedCoverUri.isNotBlank()) {
            _cachedCandidate.value = fallbackCandidate
        }

        val remoteCachedUri = prefetchCoverUrl(versionCode, coverUrl)
        return if (remoteCachedUri.isBlank()) fallbackCandidate else copy(cachedCoverUri = remoteCachedUri)
    }

    private fun prefetchCoverUrl(versionCode: Long, url: String): String {
        if (url.isBlank()) return ""
        val outputFile = coverCacheFile(versionCode, "remote-${url.stableCacheKey()}")
        if (outputFile.isFile && outputFile.length() > 0) return Uri.fromFile(outputFile).toString()

        return runCatching {
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", UPDATE_USER_AGENT)
                .build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) error("HTTP ${response.code}")
                outputFile.parentFile?.mkdirs()
                outputFile.outputStream().use { output ->
                    response.body.byteStream().use { input ->
                        input.copyTo(output)
                    }
                }
            }
            Uri.fromFile(outputFile).toString()
        }.onFailure { throwable ->
            Timber.w(throwable, "Update cover prefetch failed")
            if (outputFile.exists()) outputFile.delete()
        }.getOrDefault("")
    }

    private fun cacheCoverDataUri(versionCode: Long, dataUri: String): String {
        if (dataUri.isBlank()) return ""
        val outputFile = coverCacheFile(versionCode, "fallback-${dataUri.stableCacheKey()}")
        if (outputFile.isFile && outputFile.length() > 0) return Uri.fromFile(outputFile).toString()

        return runCatching {
            val base64 = dataUri.substringAfter("base64,", missingDelimiterValue = dataUri)
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            outputFile.parentFile?.mkdirs()
            outputFile.writeBytes(bytes)
            Uri.fromFile(outputFile).toString()
        }.onFailure { throwable ->
            Timber.w(throwable, "Update cover data URI cache failed")
            if (outputFile.exists()) outputFile.delete()
        }.getOrDefault("")
    }

    private fun coverCacheFile(versionCode: Long, source: String): File =
        File(appContext.cacheDir, "updates/release-cover-$versionCode-$source.img")

    private fun String.stableCacheKey(): String = Integer.toHexString(hashCode())

    private fun fetchManifest(): UpdateManifest {
        val urls = resolveManifestUrls()
        val errors = mutableListOf<String>()
        for (url in urls) {
            val manifest = runCatching {
                val body = client.newCall(
                    Request.Builder()
                        .url(url)
                        .header("User-Agent", UPDATE_USER_AGENT)
                        .build(),
                ).execute().use { response ->
                    if (!response.isSuccessful) {
                        error("HTTP ${response.code}")
                    }
                    response.body.string()
                }
                json.decodeFromString<UpdateManifest>(body)
            }.onFailure { throwable ->
                Timber.e(throwable, "Update manifest fetch failed: $url")
                errors += throwable.message ?: url
            }.getOrNull()

            if (manifest != null) return manifest
        }
        error(errors.firstOrNull() ?: MLang.Component.Update.Message.MissingReleaseMetadata)
    }

    private fun resolveManifestUrls(): List<String> {
        val officialUrl = BuildConfig.UPDATE_MANIFEST_URL.trim()
        val urls = linkedSetOf<String>()
        urls += officialUrl
        urls += mirrorUrlsFor(officialUrl, BuildConfig.UPDATE_MANIFEST_MIRROR_TEMPLATES)
        return urls.filter(String::isNotBlank)
    }

    private fun mirrorUrlsFor(sourceUrl: String, templates: String): List<String> {
        if (sourceUrl.isBlank() || templates.isBlank()) return emptyList()
        return templates.split('\n', ',', ';')
            .map(String::trim)
            .filter(String::isNotBlank)
            .map { template ->
                when {
                    "{url}" in template -> template.replace("{url}", sourceUrl)
                    "{encodedUrl}" in template -> template.replace("{encodedUrl}", Uri.encode(sourceUrl))
                    else -> template.trimEnd('/') + "/" + sourceUrl
                }
            }
    }

    private fun UpdateCandidate.resolveDownloadUrls(): List<String> {
        val downloadUrl = manifest.toApkDownloadUrl()
        val urls = linkedSetOf<String>()
        urls += mirrorUrlsFor(downloadUrl, BuildConfig.UPDATE_MIRROR_TEMPLATES)
        urls += downloadUrl
        return urls.filter(String::isNotBlank)
    }

    private fun UpdateCandidate.resolveDownloadFileName(): String =
        RELEASE_APK_FILE_NAME

    private fun UpdateManifest.toApkDownloadUrl(): String {
        val releaseUrl = releaseUrl.trim().trimEnd('/')
        val tag = tag.trim()
        if (releaseUrl.isBlank() || tag.isBlank()) {
            error(MLang.Component.Update.Message.MissingReleaseMetadata)
        }
        val marker = "/releases/"
        val markerIndex = releaseUrl.indexOf(marker)
        if (markerIndex < 0) error(MLang.Component.Update.Message.MissingReleaseMetadata)
        val repoUrl = releaseUrl.substring(0, markerIndex)
        return "$repoUrl/releases/download/${Uri.encode(tag)}/${Uri.encode(RELEASE_APK_FILE_NAME)}"
    }

    private suspend fun downloadToFile(url: String, outputFile: File) {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", UPDATE_USER_AGENT)
            .build()

        val call = client.newCall(request)
        activeDownloadCall = call
        try {
            call.execute().use { response ->
                if (!response.isSuccessful) error("HTTP ${response.code}")
                val body = response.body
                val contentLength = body.contentLength()
                body.byteStream().use { input ->
                    outputFile.outputStream().use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var read: Int
                        var total = 0L
                        while (input.read(buffer).also { read = it } != -1) {
                            if (downloadCancelRequested) throw UpdateDownloadCancelledException()
                            coroutineContext.ensureActive()
                            output.write(buffer, 0, read)
                            total += read
                            val progress = if (contentLength > 0) {
                                ((total * 100) / contentLength).toInt().coerceIn(0, 100)
                            } else {
                                0
                            }
                            _downloadProgress.value = UpdateDownloadProgress(
                                isDownloading = true,
                                progress = progress,
                                message = if (progress > 0) {
                                    MLang.Component.Update.Message.DownloadingWithProgress.format(progress)
                                } else {
                                    MLang.Component.Update.Message.Downloading
                                },
                            )
                        }
                    }
                }
            }
        } catch (throwable: IOException) {
            if (call.isCanceled()) {
                throw UpdateDownloadCancelledException()
            }
            throw throwable
        } finally {
            if (activeDownloadCall === call) {
                activeDownloadCall = null
            }
        }
    }

    private fun openInstaller(file: File) {
        val uri = FileProvider.getUriForFile(
            appContext,
            "${appContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        appContext.startActivity(intent)
    }

    private companion object {
        val UPDATE_USER_AGENT = "YumeBox/${BuildConfig.VERSION_NAME}"
        const val RELEASE_APK_FILE_NAME = "YumeBoxMD3-release.apk"
        const val AUTO_CHECK_INTERVAL_MS = 5 * 60 * 1000L
    }
}

internal class UpdateDownloadCancelledException : IOException(MLang.Component.Update.Message.DownloadCancelled)

internal fun Throwable.isUpdateDownloadCancelled(): Boolean =
    this is UpdateDownloadCancelledException || message == MLang.Component.Update.Message.DownloadCancelled
