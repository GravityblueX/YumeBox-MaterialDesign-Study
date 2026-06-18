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

package com.github.yumelira.yumebox.presentation.viewmodel

import com.github.yumelira.yumebox.core.model.Proxy
import com.github.yumelira.yumebox.data.model.ProxySortMode
import com.github.yumelira.yumebox.domain.model.ProxyGroupInfo
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ProxyGroupSorterTest {
    @Test
    fun defaultSortRestoresTrackedProxyOrder() = runTest {
        val sorter = ProxyGroupSorter()
        sorter.track(listOf(group(proxy("HK"), proxy("JP"), proxy("US"))))

        val sortedNames = sortedNames(
            sorter = sorter,
            groups = listOf(group(proxy("US"), proxy("HK"), proxy("JP"))),
            mode = ProxySortMode.DEFAULT,
        )

        assertEquals(listOf("HK", "JP", "US"), sortedNames)
    }

    @Test
    fun nameSortIsCaseInsensitiveAndStable() = runTest {
        val sorter = ProxyGroupSorter()
        sorter.track(listOf(group(proxy("Beta"), proxy("alpha"), proxy("Gamma"))))

        val sortedNames = sortedNames(
            sorter = sorter,
            groups = listOf(group(proxy("Gamma"), proxy("Beta"), proxy("alpha"))),
            mode = ProxySortMode.BY_NAME,
        )

        assertEquals(listOf("alpha", "Beta", "Gamma"), sortedNames)
    }

    @Test
    fun latencySortPrefersAvailableFastNodesThenUntestedThenFailed() = runTest {
        val sorter = ProxyGroupSorter()
        sorter.track(
            listOf(
                group(
                    proxy("failed", delay = -1),
                    proxy("untested", delay = 0),
                    proxy("slow", delay = 320),
                    proxy("fast", delay = 24),
                ),
            ),
        )

        val sortedNames = sortedNames(
            sorter = sorter,
            groups = listOf(
                group(
                    proxy("failed", delay = -1),
                    proxy("untested", delay = 0),
                    proxy("slow", delay = 320),
                    proxy("fast", delay = 24),
                ),
            ),
            mode = ProxySortMode.BY_LATENCY,
        )

        assertEquals(listOf("fast", "slow", "untested", "failed"), sortedNames)
    }

    @Test
    fun trackingMergesRemovedAndNewProxyNamesIntoStableDefaultOrder() = runTest {
        val sorter = ProxyGroupSorter()
        sorter.track(listOf(group(proxy("A"), proxy("B"), proxy("C"))))
        sorter.track(listOf(group(proxy("B"), proxy("D"), proxy("A"))))

        val sortedNames = sortedNames(
            sorter = sorter,
            groups = listOf(group(proxy("D"), proxy("A"), proxy("B"))),
            mode = ProxySortMode.DEFAULT,
        )

        assertEquals(listOf("A", "B", "D"), sortedNames)
    }

    private fun proxy(
        name: String,
        delay: Int = 0,
    ): Proxy = Proxy(
        name = name,
        title = name,
        subtitle = "",
        type = Proxy.Type.Shadowsocks,
        delay = delay,
    )

    private fun group(
        vararg proxies: Proxy,
    ): ProxyGroupInfo = ProxyGroupInfo(
        name = "Auto",
        type = Proxy.Type.Selector,
        proxies = proxies.toList(),
        now = proxies.firstOrNull()?.name.orEmpty(),
    )

    private suspend fun TestScope.sortedNames(
        sorter: ProxyGroupSorter,
        groups: List<ProxyGroupInfo>,
        mode: ProxySortMode,
    ): List<String> {
        val sortedGroups = sorter.bind(
            scope = backgroundScope,
            proxyGroups = MutableStateFlow(groups),
            sortMode = MutableStateFlow(mode),
        )
        val names = sortedGroups.first { it.isNotEmpty() }.single().proxies.map(Proxy::name)
        return names
    }
}
