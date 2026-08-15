// ==UserScript==
// @name         Agibot任务监控 (zero_K-Genie版)
// @namespace    http://tampermonkey.net/
// @version      7.3.0
// @description  任务列表面板 + check页面自动计数 + 通知本地应用
// @author       zero_K
// @match        https://tgs-geniestudio.agibot.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_addStyle
// @grant        GM_xmlhttpRequest
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // ====================== 配置 ======================
    const CONFIG = {
        WIN_WIDTH: 420,
        WIN_HEIGHT: 520,
        MINI_WIDTH: 200,
        MINI_HEIGHT: 42,
        INIT_TOP: 80,
        INIT_LEFT: 15,
        REFRESH_INTERVAL: 3000,
        SUCCESS_DEBOUNCE: 3000,
        MAX_LOG_COUNT: 150,
        // 本地应用通知地址
        APP_NOTIFY_URL: 'http://localhost:18080',
    };

    const API_TASK_LIST = "https://tgs-geniestudio.agibot.com/data/api/v1/collect/tasks?page_num=1&page_size=10";
    const TODAY = new Date().toISOString().slice(0, 10);
    const STORAGE_KEY_STATS = "epCompleteStat";
    const PANEL_ID = "agibot-panel";

    // ====================== 全局状态 ======================
    const State = {
        isMinimized: false,
        isDragging: false,
        dragStartX: 0, dragStartY: 0, dragStartLeft: 0, dragStartTop: 0,
        hasMoved: false,
        currentTab: 'tasks',
        isRefreshing: false,
        taskRefreshTimer: null,
        logPool: [],
        lastSuccessTime: 0,
        successObserver: null,
        isCheckPage: false,
    };

    let $ = {};

    // ====================== 存储 ======================
    const Store = {
        getStats: () => GM_getValue(STORAGE_KEY_STATS, {}),
        setStats: (s) => GM_setValue(STORAGE_KEY_STATS, s),
    };

    // ====================== 工具 ======================
    const U = {
        isCheckPage: (url) => /\/episodes\/\d+\/check/.test(url || location.href),
    };

    // ====================== 日志 ======================
    const Log = {
        add(msg, type) {
            type = type || 'info';
            const now = new Date();
            const time = now.toLocaleTimeString('zh-CN', { hour12: false });
            State.logPool.push({ time, msg, type });
            if (State.logPool.length > CONFIG.MAX_LOG_COUNT) State.logPool.shift();
            Log.render();
        },
        render() {
            if (!$.logBody) return;
            if (!State.logPool.length) { $.logBody.innerHTML = '<div class="log-empty">暂无日志</div>'; return; }
            let html = '';
            const recent = State.logPool.slice(-80);
            for (const item of recent) {
                const cls = { info: 'c-info', success: 'c-success', error: 'c-error', warn: 'c-warn' }[item.type] || 'c-info';
                html += `<div class="log-line ${cls}"><span class="log-time">${item.time}</span>${item.msg}</div>`;
            }
            $.logBody.innerHTML = html;
            $.logBody.scrollTop = $.logBody.scrollHeight;
        },
        clear() { State.logPool = []; Log.render(); Log.add('日志已清空'); },
    };

    // ====================== 统计 ======================
    const Stats = {
        today: () => (Store.getStats()[TODAY] || 0),
        add(episodeId) {
            if (Date.now() - State.lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;
            State.lastSuccessTime = Date.now();
            const s = Store.getStats();
            s[TODAY] = (s[TODAY] || 0) + 1;
            Store.setStats(s);
            Stats.render();
            Log.add(`✅ 标注成功！今日已完成 ${Stats.today()} 条`, 'success');
            
            // 通知本地应用
            Stats.notifyApp(episodeId);
        },
        notifyApp(episodeId) {
            const data = {
                type: 'review_success',
                episodeId: episodeId || 0,
                message: '标注成功'
            };
            
            GM_xmlhttpRequest({
                method: 'POST',
                url: CONFIG.APP_NOTIFY_URL,
                headers: { 'Content-Type': 'application/json' },
                data: JSON.stringify(data),
                onload(res) {
                    if (res.status === 200) {
                        Log.add('📤 已通知本地应用', 'info');
                    }
                },
                onerror() {
                    // 通知失败不影响正常使用
                }
            });
        },
        reset() {
            const s = Store.getStats(); s[TODAY] = 0; Store.setStats(s);
            Stats.render(); Log.add('📊 今日统计已重置', 'warn');
        },
        render() {
            if ($.statBadge) $.statBadge.textContent = `✅ ${Stats.today()}`;
            if ($.statFooter) $.statFooter.textContent = `今日完成: ${Stats.today()}`;
            if ($.resetBtn) $.resetBtn.textContent = `✅ 今日完成：${Stats.today()} ｜ 重置`;
        },
    };

    // ====================== API ======================
    const API = {
        fetchTasks() {
            if (State.isRefreshing) return;
            State.isRefreshing = true;
            if ($.taskBody && $.taskBody.isConnected) {
                $.taskBody.innerHTML = '<div class="loading-text">加载中...</div>';
            }

            GM_xmlhttpRequest({
                method: 'GET', url: API_TASK_LIST, timeout: 10000,
                onload: res => {
                    try {
                        const json = JSON.parse(res.responseText);
                        if (json.code === 40101) {
                            if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text err">登录失效，请刷新页面</div>';
                            State.isRefreshing = false;
                            return;
                        }
                        if (json.code !== 0) throw new Error(json.message || '接口异常');
                        API.renderTasks(json.data?.items || []);
                    } catch (e) {
                        Log.add(`❌ 任务加载失败: ${e.message}`, 'error');
                        if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text err">加载失败</div>';
                    }
                    State.isRefreshing = false;
                },
                onerror: () => {
                    Log.add('❌ 网络请求失败', 'error');
                    if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text err">网络错误</div>';
                    State.isRefreshing = false;
                },
                ontimeout: () => {
                    Log.add('❌ 请求超时', 'error');
                    if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text err">请求超时</div>';
                    State.isRefreshing = false;
                }
            });
        },
        renderTasks(items) {
            if (!$.taskBody || !$.taskBody.isConnected) return;
            if (!items.length) {
                $.taskBody.innerHTML = '<div class="empty-text">暂无任务</div>';
                return;
            }
            let html = '';
            for (const task of items) {
                const count = task.not_check_count || 0;
                const cls = count > 0 ? 'has-pending' : 'all-done';
                html += `<div class="task-item ${cls}" data-id="${task.id}">
                    <div class="task-name">${task.name || '未命名任务'}</div>
                    <div class="task-meta">
                        <span class="task-count">${count} 待审核</span>
                        <span class="task-id">#${task.id}</span>
                    </div>
                </div>`;
            }
            $.taskBody.innerHTML = html;
        }
    };

    // ====================== Check页面监控 ======================
    const CheckMonitor = {
        checkAndInit() {
            State.isCheckPage = U.isCheckPage();
            if (State.isCheckPage) {
                CheckMonitor.init();
            }
        },
        init() {
            // 监听页面变化，检测标注成功
            if (State.successObserver) {
                State.successObserver.disconnect();
            }
            
            State.successObserver = new MutationObserver((mutations) => {
                CheckMonitor.detectSuccess();
            });
            
            if (document.body) {
                State.successObserver.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true
                });
            }
            
            Log.add('📍 已进入标注页面', 'info');
        },
        detectSuccess() {
            // 检测成功提示
            const successElements = document.querySelectorAll(
                '.success-message, .toast-success, [class*="success"], .el-message--success'
            );
            
            for (const el of successElements) {
                const text = el.textContent || '';
                if (text.includes('成功') || text.includes('完成') || text.includes('success')) {
                    // 从URL提取EP ID
                    const match = location.pathname.match(/\/episodes\/(\d+)/);
                    const episodeId = match ? parseInt(match[1]) : 0;
                    Stats.add(episodeId);
                    break;
                }
            }
        },
        destroy() {
            if (State.successObserver) {
                State.successObserver.disconnect();
                State.successObserver = null;
            }
        }
    };

    // ====================== 面板构建 ======================
    function buildPanel() {
        // 检查是否已存在
        if (document.getElementById(PANEL_ID)) return false;
        
        // 注入样式
        GM_addStyle(`
            #${PANEL_ID} {
                position: fixed;
                top: ${CONFIG.INIT_TOP}px;
                left: ${CONFIG.INIT_LEFT}px;
                width: ${CONFIG.WIN_WIDTH}px;
                height: ${CONFIG.WIN_HEIGHT}px;
                background: #fff;
                border-radius: 12px;
                box-shadow: 0 8px 32px rgba(0,0,0,0.12);
                z-index: 99999;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex;
                flex-direction: column;
                overflow: hidden;
                transition: all 0.3s ease;
            }
            #${PANEL_ID}.mini {
                width: ${CONFIG.MINI_WIDTH}px;
                height: ${CONFIG.MINI_HEIGHT}px;
                overflow: hidden;
            }
            #${PANEL_ID} .panel-header {
                display: flex;
                align-items: center;
                padding: 10px 12px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: #fff;
                cursor: move;
                user-select: none;
            }
            #${PANEL_ID} .panel-title {
                flex: 1;
                font-size: 14px;
                font-weight: 600;
            }
            #${PANEL_ID} .panel-tabs {
                display: flex;
                gap: 8px;
            }
            #${PANEL_ID} .panel-tab {
                padding: 4px 8px;
                border-radius: 4px;
                cursor: pointer;
                font-size: 12px;
                opacity: 0.8;
            }
            #${PANEL_ID} .panel-tab.active {
                background: rgba(255,255,255,0.2);
                opacity: 1;
            }
            #${PANEL_ID} .act-btn {
                width: 24px;
                height: 24px;
                border: none;
                background: rgba(255,255,255,0.2);
                color: #fff;
                border-radius: 4px;
                cursor: pointer;
                margin-left: 4px;
                font-size: 12px;
            }
            #${PANEL_ID} .panel-body {
                flex: 1;
                overflow-y: auto;
                padding: 8px;
            }
            #${PANEL_ID} .panel-footer {
                padding: 8px 12px;
                border-top: 1px solid #eee;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            #${PANEL_ID} .task-item {
                padding: 10px;
                margin-bottom: 6px;
                background: #f8f9fa;
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.2s;
            }
            #${PANEL_ID} .task-item:hover {
                background: #e9ecef;
            }
            #${PANEL_ID} .task-item.has-pending {
                border-left: 3px solid #28a745;
            }
            #${PANEL_ID} .task-item.all-done {
                border-left: 3px solid #6c757d;
                opacity: 0.7;
            }
            #${PANEL_ID} .task-name {
                font-size: 13px;
                font-weight: 500;
                margin-bottom: 4px;
            }
            #${PANEL_ID} .task-meta {
                display: flex;
                justify-content: space-between;
                font-size: 11px;
                color: #6c757d;
            }
            #${PANEL_ID} .task-count {
                color: #28a745;
                font-weight: 500;
            }
            #${PANEL_ID} .log-line {
                font-size: 12px;
                padding: 3px 0;
                border-bottom: 1px solid #f0f0f0;
            }
            #${PANEL_ID} .log-time {
                color: #999;
                margin-right: 8px;
            }
            #${PANEL_ID} .c-info { color: #333; }
            #${PANEL_ID} .c-success { color: #28a745; }
            #${PANEL_ID} .c-error { color: #dc3545; }
            #${PANEL_ID} .c-warn { color: #ffc107; }
            #${PANEL_ID} .log-empty, #${PANEL_ID} .empty-text, #${PANEL_ID} .loading-text {
                text-align: center;
                color: #999;
                padding: 20px;
                font-size: 13px;
            }
            #${PANEL_ID} .empty-text.err { color: #dc3545; }
            #${PANEL_ID} .stat-badge {
                background: #28a745;
                color: #fff;
                padding: 2px 8px;
                border-radius: 10px;
                font-size: 12px;
                font-weight: 600;
            }
            #${PANEL_ID} .footer-btn {
                border: none;
                background: #f0f0f0;
                padding: 4px 8px;
                border-radius: 4px;
                cursor: pointer;
                font-size: 11px;
            }
            #${PANEL_ID} .footer-btn:hover {
                background: #e0e0e0;
            }
        `);

        // 创建面板
        const panel = document.createElement('div');
        panel.id = PANEL_ID;
        panel.innerHTML = `
            <div class="panel-header">
                <div class="panel-title">Agibot 任务监控</div>
                <div class="panel-tabs">
                    <div class="panel-tab active" data-tab="tasks">任务</div>
                    <div class="panel-tab" data-tab="logs">日志</div>
                </div>
                <span class="stat-badge">✅ 0</span>
                <button class="act-btn min-btn" title="最小化">—</button>
                <button class="act-btn close-btn" title="关闭">×</button>
            </div>
            <div class="panel-body">
                <div class="tab-content" data-tab="tasks">
                    <div class="task-body">加载中...</div>
                </div>
                <div class="tab-content" data-tab="logs" style="display:none">
                    <div class="log-body">暂无日志</div>
                </div>
            </div>
            <div class="panel-footer">
                <span class="stat-footer">今日完成: 0</span>
                <button class="footer-btn reset-btn">重置统计</button>
                <button class="footer-btn clear-log-btn">清空日志</button>
            </div>
        `;
        
        document.body.appendChild(panel);
        
        // 获取元素引用
        $ = {
            panel: panel,
            header: panel.querySelector('.panel-header'),
            minBtn: panel.querySelector('.min-btn'),
            closeBtn: panel.querySelector('.close-btn'),
            taskBody: panel.querySelector('.task-body'),
            logBody: panel.querySelector('.log-body'),
            statBadge: panel.querySelector('.stat-badge'),
            statFooter: panel.querySelector('.stat-footer'),
            resetBtn: panel.querySelector('.reset-btn'),
            clearLogBtn: panel.querySelector('.clear-log-btn'),
            tabs: panel.querySelectorAll('.panel-tab'),
            tabContents: panel.querySelectorAll('.tab-content'),
        };
        
        return true;
    }

    // ====================== 事件绑定 ======================
    function bindEvents() {
        // Tab切换
        $.tabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                e.stopPropagation();
                const tabName = tab.dataset.tab;
                $.tabs.forEach(t => t.classList.remove('active'));
                tab.classList.add('active');
                $.tabContents.forEach(c => {
                    c.style.display = c.dataset.tab === tabName ? 'block' : 'none';
                });
                State.currentTab = tabName;
            });
        });

        // 最小化切换
        const toggleMini = (e) => {
            e.stopPropagation();
            State.isMinimized = !State.isMinimized;
            $.panel.classList.toggle('mini', State.isMinimized);
            $.minBtn.textContent = State.isMinimized ? '□' : '—';
            $.minBtn.title = State.isMinimized ? '还原' : '最小化';
        };
        $.minBtn.addEventListener('click', toggleMini);

        // 关闭
        $.closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            cleanup();
        });

        // 双击标题切换最小化
        $.header.addEventListener('dblclick', (e) => {
            if (e.target.closest('.act-btn') || e.target.closest('.panel-tab')) return;
            toggleMini(e);
        });

        // 拖拽
        $.header.addEventListener('mousedown', (e) => {
            if (e.target.closest('.act-btn') || e.target.closest('.panel-tab')) return;
            e.preventDefault();
            const rect = $.panel.getBoundingClientRect();
            State.isDragging = true;
            State.dragStartX = e.clientX;
            State.dragStartY = e.clientY;
            State.dragStartLeft = rect.left;
            State.dragStartTop = rect.top;
            State.hasMoved = false;
        });

        document.addEventListener('mousemove', (e) => {
            if (!State.isDragging) return;
            const dx = e.clientX - State.dragStartX;
            const dy = e.clientY - State.dragStartY;
            if (Math.abs(dx) < 2 && Math.abs(dy) < 2) return;
            State.hasMoved = true;
            let nx = State.dragStartLeft + dx;
            let ny = State.dragStartTop + dy;
            nx = Math.max(0, Math.min(nx, window.innerWidth - $.panel.offsetWidth));
            ny = Math.max(0, Math.min(ny, window.innerHeight - $.panel.offsetHeight));
            $.panel.style.left = nx + 'px';
            $.panel.style.top = ny + 'px';
        });

        document.addEventListener('mouseup', (e) => {
            if (!State.isDragging) return;
            const moved = State.hasMoved;
            State.isDragging = false;
            State.hasMoved = false;
            if (State.isMinimized && !moved && !e.target.closest('.act-btn')) {
                toggleMini(e);
            }
        });

        // 重置统计
        $.resetBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            if (confirm('确认重置今日标注统计？')) Stats.reset();
        });

        // 清空日志
        $.clearLogBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            Log.clear();
        });

        // 窗口大小调整
        window.addEventListener('resize', () => {
            if (!$.panel || !$.panel.isConnected) return;
            const rect = $.panel.getBoundingClientRect();
            if (rect.right > window.innerWidth) $.panel.style.left = (window.innerWidth - rect.width - 10) + 'px';
            if (rect.bottom > window.innerHeight) $.panel.style.top = (window.innerHeight - rect.height - 10) + 'px';
            if (rect.left < 0) $.panel.style.left = '0px';
            if (rect.top < 0) $.panel.style.top = '0px';
        });
    }

    // ====================== 清理 ======================
    function cleanup() {
        if (State.taskRefreshTimer) clearInterval(State.taskRefreshTimer);
        CheckMonitor.destroy();
        if ($.panel && $.panel.isConnected) $.panel.remove();
        $ = {};
        State.isDragging = false;
    }

    // ====================== 启动 ======================
    function init() {
        // 如果已存在面板，直接跳过
        if (document.getElementById(PANEL_ID)) return;

        if (!buildPanel()) return;
        bindEvents();

        Stats.render();
        Log.add('✅ 任务监控面板已启动', 'success');

        // 任务列表刷新
        API.fetchTasks();
        State.taskRefreshTimer = setInterval(() => {
            if (!$.panel || !$.panel.isConnected) {
                clearInterval(State.taskRefreshTimer);
                return;
            }
            API.fetchTasks();
        }, CONFIG.REFRESH_INTERVAL);

        // check页面检测
        CheckMonitor.checkAndInit();

        // 监听URL变化
        let lastUrl = location.href;
        setInterval(() => {
            if (location.href !== lastUrl) {
                lastUrl = location.href;
                CheckMonitor.checkAndInit();
                Log.add(`🔄 页面切换: ${U.isCheckPage() ? 'check标注页' : '其他页面'}`, 'info');
            }
        }, 1000);

        // 暴露全局计数函数
        window.markEpSuccess = (episodeId) => { Stats.add(episodeId); };

        window.addEventListener('beforeunload', () => {
            cleanup();
        });
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        setTimeout(init, 500);
    } else {
        window.addEventListener('load', () => setTimeout(init, 500));
    }
})();
