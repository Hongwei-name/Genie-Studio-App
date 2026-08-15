// ==UserScript==
// @name         Agibot任务监控
// @namespace    http://tampermonkey.net/
// @version      7.2.1
// @description  任务列表面板 + check页面自动计数（修复重复面板）
// @author       You
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
        add() {
            if (Date.now() - State.lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;
            State.lastSuccessTime = Date.now();
            const s = Store.getStats();
            s[TODAY] = (s[TODAY] || 0) + 1;
            Store.setStats(s);
            Stats.render();
            Log.add(`✅ 标注成功！今日已完成 ${Stats.today()} 条`, 'success');
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
                        const list = (json.data && Array.isArray(json.data.list)) ? json.data.list : [];

                        let total = 0;
                        list.forEach(t => total += Number(t.not_check_count || 0));
                        if ($.countBadge && $.countBadge.isConnected) $.countBadge.textContent = `📊 ${total}待审`;

                        if (!list.length) {
                            if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text">✨ 暂无任务</div>';
                            State.isRefreshing = false;
                            return;
                        }

                        let html = '';
                        list.forEach(t => {
                            const n = Number(t.not_check_count || 0);
                            html += `<div class="task-row" data-tid="${t.id}">
                                <span class="t-id">${t.id}</span>
                                <span class="t-name" title="${(t.name || '').replace(/"/g, '&quot;')}">${t.name || '未命名'}</span>
                                <span class="t-count">${n}</span>
                                <div class="t-btns">${n <= 0 ? '<span class="no-ep">无</span>' : '<span class="loading-ep">加载中...</span>'}</div>
                            </div>`;
                        });
                        if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = html;

                        setTimeout(() => {
                            document.querySelectorAll('.task-row').forEach(row => {
                                const tid = row.dataset.tid;
                                const n = Number(row.querySelector('.t-count').textContent);
                                const container = row.querySelector('.t-btns');
                                if (n <= 0) return;
                                API.fetchJobs(tid, container);
                            });
                        }, 100);
                        State.isRefreshing = false;
                    } catch (e) {
                        if ($.taskBody && $.taskBody.isConnected) $.taskBody.innerHTML = '<div class="empty-text err">解析失败</div>';
                        State.isRefreshing = false;
                    }
                },
                onerror: () => { State.isRefreshing = false; },
                ontimeout: () => { State.isRefreshing = false; },
            });
        },

        fetchJobs(taskId, container) {
            const p = `task_id=${taskId}&page_num=1&page_size=10&episode_status%5B%5D=9`;
            GM_xmlhttpRequest({
                method: 'GET',
                url: `https://tgs-geniestudio.agibot.com/data/api/v1/collect/task/job?${p}`,
                timeout: 8000,
                onload: res => {
                    try {
                        const json = JSON.parse(res.responseText);
                        if (json.code === 40101) { container.innerHTML = '<span class="no-ep err">失效</span>'; return; }
                        const jobs = (json.data && Array.isArray(json.data.list)) ? json.data.list : [];
                        if (!jobs.length) { container.innerHTML = '<span class="no-ep">无Job</span>'; return; }
                        const ids = [];
                        jobs.forEach(j => { if (Array.isArray(j.variables)) j.variables.forEach(v => { if (v.job_id) ids.push(v.job_id); }); });
                        if (!ids.length) { container.innerHTML = '<span class="no-ep">无Job</span>'; return; }
                        container.innerHTML = '<span class="loading-ep">加载中...</span>';
                        ids.forEach(jid => API.fetchEps(taskId, jid, container));
                    } catch (e) { }
                },
                onerror: () => { },
            });
        },

        fetchEps(taskId, jobId, container) {
            GM_xmlhttpRequest({
                method: 'GET',
                url: `https://tgs-geniestudio.agibot.com/data/api/v1/collect/tasks/${taskId}/jobs/${jobId}/episodes?status%5B%5D=9&with_status_count=true&page_num=1&page_size=10`,
                timeout: 8000,
                onload: res => {
                    try {
                        const json = JSON.parse(res.responseText);
                        if (json.code === 40101) return;
                        const eps = (json.data && Array.isArray(json.data.list)) ? json.data.list : [];
                        if (!eps.length) return;
                        const loadEl = container.querySelector('.loading-ep');
                        if (loadEl) loadEl.remove();
                        eps.forEach(ep => {
                            if (!ep.id) return;
                            const btn = document.createElement('button');
                            btn.className = 'ep-btn';
                            btn.textContent = `EP${ep.id}`;
                            btn.onclick = e => {
                                e.stopPropagation();
                                window.open(
                                    `https://tgs-geniestudio.agibot.com/data/collection/tasks/${taskId}/jobs/${jobId}/episodes/${ep.id}/check`,
                                    '_blank'
                                );
                            };
                            container.appendChild(btn);
                        });
                    } catch (e) { }
                },
            });
        },
    };

    // ====================== Check页面监听 ======================
    const CheckMonitor = {
        init() {
            if (State.successObserver) State.successObserver.disconnect();
            State.successObserver = new MutationObserver(muts => {
                for (const m of muts) {
                    for (const n of m.addedNodes) {
                        if (n.nodeType !== 1) continue;
                        const t = n.matches('.el-message, .el-message-box') ? n : n.querySelector('.el-message, .el-message-box');
                        if (!t || t.dataset.marked) continue;
                        if (t.textContent.includes('标注成功')) {
                            t.dataset.marked = '1';
                            Stats.add();
                        }
                    }
                }
            });
            State.successObserver.observe(document.body, { childList: true, subtree: true });
            State.isCheckPage = true;
            Log.add('🖥 检测到check页面，标注计数已启用', 'success');
        },

        destroy() {
            if (State.successObserver) {
                State.successObserver.disconnect();
                State.successObserver = null;
            }
            State.isCheckPage = false;
        },

        checkAndInit() {
            if (U.isCheckPage()) {
                if (!State.isCheckPage) CheckMonitor.init();
            } else {
                if (State.isCheckPage) CheckMonitor.destroy();
            }
        },
    };

    // ====================== 样式 ======================
    GM_addStyle(`
        #${PANEL_ID} {
            position: fixed; top: ${CONFIG.INIT_TOP}px; left: ${CONFIG.INIT_LEFT}px;
            width: ${CONFIG.WIN_WIDTH}px; height: ${CONFIG.WIN_HEIGHT}px;
            background: #fff; color: #333; font-family: -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
            font-size: 12px; line-height: 1.4; border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.15); border: 1px solid #e0e0e0;
            z-index: 999999; display: flex; flex-direction: column; overflow: hidden;
            user-select: none; transition: width 0.2s, height 0.2s, border-radius 0.2s;
        }
        #${PANEL_ID}.mini {
            width: ${CONFIG.MINI_WIDTH}px !important; height: ${CONFIG.MINI_HEIGHT}px !important;
            border-radius: 21px; cursor: pointer;
        }
        #${PANEL_ID}.mini .panel-body { display: none !important; }
        #${PANEL_ID}.mini .panel-footer { display: none !important; }
        #${PANEL_ID}.mini .panel-tabs { display: none !important; }
        #${PANEL_ID}.mini .panel-header { border-radius: 21px; }

        .panel-header {
            height: 40px; min-height: 40px; display: flex; align-items: center;
            padding: 0 10px; background: #3674d9; color: #fff;
            flex-shrink: 0; cursor: move; gap: 8px;
        }
        .panel-header .title { font-weight:600; font-size:13px; flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .panel-header .badges { display:flex; gap:6px; font-size:10px; flex-shrink:0; }
        .panel-header .badge { background:rgba(255,255,255,0.2); padding:2px 8px; border-radius:10px; white-space:nowrap; }
        .panel-header .actions { display:flex; gap:2px; flex-shrink:0; }
        .panel-header .act-btn {
            width:26px; height:26px; line-height:26px; text-align:center; cursor:pointer;
            border-radius:4px; font-size:16px; opacity:0.85; transition:all 0.15s; background:none; border:none; color:#fff;
        }
        .panel-header .act-btn:hover { background:rgba(255,255,255,0.25); opacity:1; }
        #minBtn { font-size:20px; font-weight:bold; line-height:24px; }
        #closeBtn { font-size:20px; line-height:24px; }

        .panel-tabs {
            display:flex; background:#f5f7fa; border-bottom:1px solid #e4e7ed; flex-shrink:0;
        }
        .panel-tab {
            flex:1; padding:8px; text-align:center; cursor:pointer; font-size:11px; font-weight:500;
            color:#909399; border-bottom:2px solid transparent; transition:all 0.2s;
        }
        .panel-tab:hover { color:#606266; }
        .panel-tab.active { color:#3674d9; border-bottom-color:#3674d9; }

        .panel-body {
            flex:1; overflow-y:auto; min-height:0;
        }
        .panel-body::-webkit-scrollbar { width:5px; }
        .panel-body::-webkit-scrollbar-thumb { background:#cbd5e0; border-radius:4px; }

        .tab-content { height:100%; }

        .task-head {
            display:grid; grid-template-columns:70px 1fr 55px 1fr; gap:6px; padding:8px 10px;
            font-size:11px; font-weight:600; color:#606266; background:#f5f7fa;
            position:sticky; top:0; z-index:2; border-bottom:1px solid #e4e7ed;
        }
        .task-row {
            display:grid; grid-template-columns:70px 1fr 55px 1fr; gap:6px; padding:7px 10px;
            border-bottom:1px solid #f0f0f0; font-size:11px; align-items:center;
        }
        .task-row:nth-child(odd) { background:#fafbfc; }
        .task-row:hover { background:#f0f4ff; }
        .t-id { color:#1e293b; font-weight:600; }
        .t-name { color:#334155; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        .t-count { color:#e53e3e; font-weight:700; text-align:right; }
        .t-btns { display:flex; gap:3px; flex-wrap:wrap; }
        .ep-btn {
            padding:3px 8px; font-size:10px; border:none; border-radius:4px;
            background:#409eff; color:#fff; cursor:pointer; white-space:nowrap; transition:background 0.2s;
        }
        .ep-btn:hover { background:#337ecc; }
        .no-ep { font-size:10px; color:#a0aec0; }
        .loading-ep { font-size:10px; color:#a0aec0; }
        .loading-text { text-align:center; color:#8899aa; padding:30px; }
        .empty-text { text-align:center; color:#8899aa; padding:30px; font-size:12px; }
        .empty-text.err { color:#f56c6c; }

        .log-body { padding:6px 10px; background:#1a1a2e; min-height:100%; }
        .log-empty { text-align:center; color:#5a5e66; padding:30px; font-size:11px; }
        .log-line {
            display:flex; gap:6px; padding:3px 0; font-size:11px; line-height:1.6;
            font-family:'Consolas','Courier New',monospace; border-left:2px solid transparent; padding-left:6px;
        }
        .log-time { color:#5a5e66; font-size:10px; flex-shrink:0; }
        .c-info { color:#b0c0d0; }
        .c-success { color:#7ee787; font-weight:500; }
        .c-error { color:#f5657c; font-weight:500; }
        .c-warn { color:#f0a854; font-weight:500; }

        .panel-footer {
            height:34px; min-height:34px; display:flex; align-items:center;
            padding:0 10px; background:#f8fafc; border-top:1px solid #e2e8f0;
            font-size:10px; color:#64748b; flex-shrink:0; justify-content:space-between;
        }
        .stat-reset {
            color:#dd6b20; cursor:pointer; font-weight:500; font-size:10px;
            background:rgba(221,107,32,0.08); padding:2px 10px; border-radius:12px;
            transition:background 0.2s; border:none; font-family:inherit;
        }
        .stat-reset:hover { background:rgba(221,107,32,0.18); }
        .footer-btn {
            background:none; border:none; color:#909399; cursor:pointer; font-size:10px;
            font-family:inherit; padding:2px 6px; border-radius:3px;
        }
        .footer-btn:hover { color:#606266; background:#f0f0f0; }
    `);

    // ====================== 面板构建 ======================
    function buildPanel() {
        // 【关键】先检查是否已存在，避免重复创建
        if (document.getElementById(PANEL_ID)) return false;

        const panel = document.createElement('div');
        panel.id = PANEL_ID;
        panel.innerHTML = `
            <div class="panel-header" id="panelHeader">
                <span class="title">📌 Agibot任务监控</span>
                <span class="badges">
                    <span class="badge" id="countBadge">📊 ...待审</span>
                    <span class="badge" id="statBadge">✅ ${Stats.today()}</span>
                </span>
                <span class="actions">
                    <span class="act-btn" id="minBtn" title="最小化">—</span>
                    <span class="act-btn" id="closeBtn" title="关闭">✕</span>
                </span>
            </div>
            <div class="panel-tabs">
                <div class="panel-tab active" data-tab="tasks">📋 任务列表</div>
                <div class="panel-tab" data-tab="log">📜 日志</div>
            </div>
            <div class="panel-body" id="panelBody">
                <div id="tab-tasks" class="tab-content">
                    <div class="task-head"><span>ID</span><span>名称</span><span>待审</span><span>入口</span></div>
                    <div id="taskBody"><div class="loading-text">加载中...</div></div>
                </div>
                <div id="tab-log" class="tab-content" style="display:none;">
                    <div class="log-body" id="logBody"><div class="log-empty">暂无日志</div></div>
                </div>
            </div>
            <div class="panel-footer">
                <span>今日完成: ${Stats.today()}</span>
                <span>
                    <button class="stat-reset" id="resetBtn">✅ 今日完成：${Stats.today()} ｜ 重置</button>
                    <button class="footer-btn" id="clearLogBtn">清空日志</button>
                </span>
            </div>
        `;
        document.body.appendChild(panel);

        // 缓存DOM
        $ = {
            panel,
            header: document.getElementById('panelHeader'),
            countBadge: document.getElementById('countBadge'),
            statBadge: document.getElementById('statBadge'),
            statFooter: panel.querySelector('.panel-footer span'),
            minBtn: document.getElementById('minBtn'),
            closeBtn: document.getElementById('closeBtn'),
            tabs: panel.querySelectorAll('.panel-tab'),
            taskBody: document.getElementById('taskBody'),
            logBody: document.getElementById('logBody'),
            resetBtn: document.getElementById('resetBtn'),
            clearLogBtn: document.getElementById('clearLogBtn'),
        };

        bindEvents();
        return true;
    }

    // ====================== 事件绑定 ======================
    function bindEvents() {
        // Tab切换
        $.tabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                e.stopPropagation();
                const name = tab.dataset.tab;
                State.currentTab = name;
                $.tabs.forEach(t => t.classList.remove('active'));
                tab.classList.add('active');
                document.querySelectorAll('.tab-content').forEach(c => c.style.display = 'none');
                document.getElementById(`tab-${name}`).style.display = 'block';
                if (name === 'log') Log.render();
            });
        });

        // 最小化
        const toggleMini = (e) => {
            if (e) e.stopPropagation();
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
        // 【关键】如果已存在面板，说明已初始化，直接跳过
        if (document.getElementById(PANEL_ID)) return;

        if (!buildPanel()) return; // 双重保险

        Stats.render();
        Log.add('✅ 任务监控面板已启动（5秒刷新）', 'success');

        // 任务列表刷新
        API.fetchTasks();
        State.taskRefreshTimer = setInterval(() => {
            // 确保面板还存在
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
        window.markEpSuccess = () => { Stats.add(); };

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