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

import kotlinx.serialization.Serializable

@Serializable
data class UpdateManifest(
    val manifestUrl: String = "",
    val channel: String = "",
    val tag: String = "",
    val versionName: String = "",
    val versionCode: Long = 0L,
    val releaseNotes: String = "",
    val releaseUrl: String = "",
    val coverUrl: String = "",
    val coverDataUri: String = "",
)

data class UpdateCandidate(
    val manifest: UpdateManifest,
    val cachedCoverUri: String = "",
) {
    val manifestUrl: String get() = manifest.manifestUrl
    val tag: String get() = manifest.tag
    val versionName: String get() = manifest.versionName
    val versionCode: Long get() = manifest.versionCode
    val releaseNotes: String get() = manifest.releaseNotes
    val releaseUrl: String get() = manifest.releaseUrl
    val coverUrl: String get() = manifest.coverUrl
    val coverDataUri: String get() = manifest.coverDataUri
}

data class UpdateDownloadProgress(
    val isDownloading: Boolean = false,
    val progress: Int = 0,
    val message: String = "",
)
