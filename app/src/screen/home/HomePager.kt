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


package com.github.yumelira.yumebox.screen.home
import com.github.yumelira.yumebox.presentation.theme.UiDp
import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.github.yumelira.yumebox.common.AppConstants
import com.github.yumelira.yumebox.common.util.toast
import com.github.yumelira.yumebox.domain.model.TrafficData
import com.github.yumelira.yumebox.presentation.component.LocalNavigator
import com.github.yumelira.yumebox.presentation.component.ScreenLazyColumn
import com.github.yumelira.yumebox.presentation.component.TopBar
import com.github.yumelira.yumebox.presentation.component.combinePaddingValues
import com.github.yumelira.yumebox.presentation.icon.AppMd3Icons
import com.ramcosta.composedestinations.generated.destinations.TrafficStatisticsScreenDestination
import dev.oom_wg.purejoy.mlang.MLang
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel

@Composable
fun HomePager(
    mainInnerPadding: PaddingValues,
    isActive: Boolean,
) {
    val homeViewModel = koinViewModel<HomeViewModel>()
    val navigator = LocalNavigator.current

    val controlState by homeViewModel.controlState.collectAsState()
    val uiState by homeViewModel.uiState.collectAsState()
    val trafficNow by homeViewModel.trafficNow.collectAsState()
    val profiles by homeViewModel.profiles.collectAsState()
    val profilesLoaded by homeViewModel.profilesLoaded.collectAsState()
    val ipMonitoringState by homeViewModel.ipMonitoringState.collectAsState()
    val recommendedProfile by homeViewModel.recommendedProfile.collectAsState()
    val hasEnabledProfile by homeViewModel.hasEnabledProfile.collectAsState(initial = false)
    val currentProfile by homeViewModel.currentProfile.collectAsState()
    val selectedServerName by homeViewModel.selectedServerName.collectAsState()
    val selectedServerPing by homeViewModel.selectedServerPing.collectAsState()
    val speedHistory by homeViewModel.speedHistory.collectAsState()
    val testingCurrentNodeDelay by homeViewModel.testingCurrentNodeDelay.collectAsState()
    val proxyMode by homeViewModel.proxyMode.collectAsState()
    val tunnelMode by homeViewModel.tunnelMode.collectAsState()
    val context = LocalContext.current
    val hapticFeedback = LocalHapticFeedback.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        homeViewModel.refreshProxyMode()
    }

    LaunchedEffect(isActive) {
        homeViewModel.setHomeScreenActive(isActive)
    }

    DisposableEffect(homeViewModel) {
        onDispose {
            homeViewModel.setHomeScreenActive(false)
        }
    }

    DisposableEffect(lifecycleOwner, homeViewModel) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                homeViewModel.reconcileRuntimeState()
                homeViewModel.refreshProxyMode()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            context.toast(it, Toast.LENGTH_LONG)
            homeViewModel.consumeError()
        }
    }

    LaunchedEffect(uiState.message) {
        uiState.message?.let {
            context.toast(it, Toast.LENGTH_SHORT)
            homeViewModel.consumeMessage()
        }
    }


    val isRunning = controlState == HomeProxyControlState.Running
    val isProxyEnabled = profilesLoaded && profiles.isNotEmpty() && controlState.canInteract

    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            TopBar(
                title = MLang.Home.Title,
                actions = {
                    IconButton(
                        enabled = isRunning && !testingCurrentNodeDelay,
                        onClick = {
                            hapticFeedback.performHapticFeedback(HapticFeedbackType.VirtualKey)
                            homeViewModel.testCurrentNodeDelay()
                        },
                    ) {
                        Icon(
                            imageVector = AppMd3Icons.Action.SpeedTest,
                            contentDescription = MLang.Proxy.Action.Test,
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        ScreenLazyColumn(
            innerPadding = combinePaddingValues(innerPadding, mainInnerPadding),
        ) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = AppConstants.UI.DEFAULT_HORIZONTAL_PADDING),
                    horizontalAlignment = Alignment.Start,
                    verticalArrangement = Arrangement.spacedBy(AppConstants.UI.DEFAULT_VERTICAL_SPACING)
                ) {

                    StudyStatusCard(
                        isRunning = isRunning,
                        profileName = currentProfile?.name,
                        serverName = selectedServerName,
                        serverPing = selectedServerPing,
                        tunnelMode = tunnelMode,
                    )

                    StudyGuideCard(
                        isRunning = isRunning,
                        hasEnabledProfile = hasEnabledProfile,
                        recommendedProfileName = recommendedProfile?.name,
                    )

                    TrafficDisplay(
                        trafficNow = if (isRunning) {
                            TrafficData.from(trafficNow)
                        } else {
                            TrafficData.ZERO
                        },
                        profileName = currentProfile?.name?.takeIf { isRunning },
                        tunnelMode = tunnelMode.takeIf { isRunning },
                        controlState = controlState,
                        proxyMode = proxyMode,
                        isEnabled = isProxyEnabled,
                        onClick = {
                            if (!hasEnabledProfile || recommendedProfile == null) {
                                context.toast(MLang.ProfilesVM.Error.ProfileNotExist)
                                return@TrafficDisplay
                            }
                            hapticFeedback.performHapticFeedback(HapticFeedbackType.VirtualKey)
                            handleProxyToggle(
                                isRunning = isRunning,
                                recommendedProfile = recommendedProfile,
                                onStart = { profile ->
                                    homeViewModel.startProxy(
                                        profileId = profile.uuid.toString(),
                                        mode = null
                                    )
                                },
                                onStop = {
                                    coroutineScope.launch { homeViewModel.stopProxy() }
                                }
                            )
                        }
                    )

                    Column(verticalArrangement = Arrangement.spacedBy(UiDp.dp16)) {
                        NodeInfoDisplay(
                            serverName = selectedServerName.takeIf { isRunning },
                            serverPing = selectedServerPing.takeIf { isRunning }
                        )
                        IpInfoDisplay(
                            state = ipMonitoringState
                        )
                    }

                    SpeedChart(
                        speedHistory = speedHistory,
                        isRunning = isRunning,
                        animateIdle = isActive,
                        onClick = {
                            navigator.navigate(TrafficStatisticsScreenDestination) {
                                launchSingleTop = true
                            }
                        }
                    )
                }
            }

            item { Spacer(modifier = Modifier.height(UiDp.dp32)) }
        }
    }
}

private fun com.github.yumelira.yumebox.core.model.TunnelState.Mode?.studyDisplayName(): String =
    this?.name ?: "--"

@Composable
private fun StudyStatusCard(
    isRunning: Boolean,
    profileName: String?,
    serverName: String?,
    serverPing: Int?,
    tunnelMode: com.github.yumelira.yumebox.core.model.TunnelState.Mode?,
    modifier: Modifier = Modifier,
) {
    val statusText = if (isRunning) "代理运行中" else "代理未启动"
    val statusTone = if (isRunning) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    val nodeText = serverName?.takeIf { it.isNotBlank() } ?: "未选择节点"
    val profileText = profileName?.takeIf { it.isNotBlank() } ?: "未选择配置"
    val tunnelText = tunnelMode.studyDisplayName()
    val pingText = serverPing?.takeIf { it > 0 && it <= 1000 }?.let { "${it}ms" } ?: "--"

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(
            modifier = Modifier.padding(UiDp.dp16),
            verticalArrangement = Arrangement.spacedBy(UiDp.dp14),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(UiDp.dp4)) {
                    Text(
                        text = "YUMEBOX STUDY",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "暗色学习面板",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Surface(
                    shape = MaterialTheme.shapes.small,
                    color = statusTone.copy(alpha = 0.12f),
                    border = BorderStroke(1.dp, statusTone.copy(alpha = 0.32f)),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = UiDp.dp10, vertical = UiDp.dp6),
                        horizontalArrangement = Arrangement.spacedBy(UiDp.dp6),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Surface(
                            modifier = Modifier.size(8.dp),
                            shape = MaterialTheme.shapes.small,
                            color = statusTone,
                        ) {}
                        Text(
                            text = statusText,
                            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                            color = statusTone,
                        )
                    }
                }
            }

            Text(
                text = profileText,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface,
            )

            Column(verticalArrangement = Arrangement.spacedBy(UiDp.dp8)) {
                StudyInfoRow(label = "当前节点", value = nodeText)
                StudyInfoRow(label = "运行模式", value = tunnelText)
                StudyInfoRow(label = "节点延迟", value = pingText)
            }
        }
    }
}

@Composable
private fun StudyInfoRow(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.width(UiDp.dp16))
        Text(
            text = value,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun StudyGuideCard(
    isRunning: Boolean,
    hasEnabledProfile: Boolean,
    recommendedProfileName: String?,
    modifier: Modifier = Modifier,
) {
    val title: String
    val summary: String
    val steps: List<String>

    when {
        isRunning -> {
            title = "学习提示：观察运行状态"
            summary = "代理已经启动，现在可以重点观察节点、延迟、实时流量和 IP 信息如何随运行时变化。"
            steps = listOf(
                "点击右上角测速按钮，可以测试当前节点延迟。",
                "点击速度曲线，可以进入更详细的流量统计。",
                "尝试切换节点后回到首页，观察卡片状态如何刷新。",
            )
        }

        hasEnabledProfile -> {
            title = "学习提示：准备启动代理"
            summary = "已经有可用配置：${recommendedProfileName ?: "当前启用配置"}。你可以点击流量区域启动代理。"
            steps = listOf(
                "确认配置来源可信。",
                "点击 DOWNLOAD / UPLOAD 区域启动或停止代理。",
                "首次启动可能需要系统 VPN 权限确认。",
            )
        }

        else -> {
            title = "学习提示：先添加配置"
            summary = "目前还没有启用的配置。学习版建议先从配置页导入一个订阅或本地配置。"
            steps = listOf(
                "进入底部的配置页。",
                "添加订阅链接或导入本地配置文件。",
                "启用配置后回到首页，再尝试启动代理。",
            )
        }
    }

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceContainer,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.72f)),
    ) {
        Column(
            modifier = Modifier.padding(UiDp.dp16),
            verticalArrangement = Arrangement.spacedBy(UiDp.dp10),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "STUDY GUIDE",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = summary,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Column(verticalArrangement = Arrangement.spacedBy(UiDp.dp8)) {
                steps.forEachIndexed { index, step ->
                    StudyStepRow(index = index + 1, text = step)
                }
            }
        }
    }
}

@Composable
private fun StudyStepRow(
    index: Int,
    text: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(UiDp.dp10),
        verticalAlignment = Alignment.Top,
    ) {
        Surface(
            modifier = Modifier.size(22.dp),
            shape = MaterialTheme.shapes.small,
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.64f)),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = index.toString(),
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Text(
            text = text,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun handleProxyToggle(
    isRunning: Boolean,
    recommendedProfile: com.github.yumelira.yumebox.service.runtime.entity.Profile?,
    onStart: (com.github.yumelira.yumebox.service.runtime.entity.Profile) -> Unit,
    onStop: () -> Unit
) {
    if (!isRunning) {
        recommendedProfile?.let { profile -> onStart(profile) }
    } else {
        onStop()
    }
}
