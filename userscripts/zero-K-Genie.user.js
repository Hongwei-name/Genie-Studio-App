// ==UserScript==
// @name         zero_K-Genie Review Helper
// @namespace    http://tampermonkey.net/
// @version      3.0.1
// @description  优化初始状态为最小化
// @author       You
// @match        https://tgs-geniestudio.agibot.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_addStyle
// @grant        GM_xmlhttpRequest
// @grant        GM_openInTab
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    const PANEL_ID = "agibot-monitor-panel-v2";
    const RESOURCE_PANEL_ID = "agibot-resource-panel";
    const SCRIPT_KEY = "__AGIBOT_MONITOR_V2__";

    function killDuplicatePanels() {
        try {
            document.querySelectorAll('#' + PANEL_ID).forEach(function(el, i) {
                if (i > 0) el.remove();
            });
            document.querySelectorAll('#' + RESOURCE_PANEL_ID).forEach(function(el, i) {
                if (i > 0) el.remove();
            });
        } catch (e) {}
    }

    if (window[SCRIPT_KEY] && window[SCRIPT_KEY].instanceId) {
        console.log('[Agibot Monitor] 脚本实例已存在，终止重复运行');
        killDuplicatePanels();
        return;
    }

    const INSTANCE = window[SCRIPT_KEY] = {
        instanceId: Date.now(),
        phase: 'idle',
        navigationTimer: null,
        navigationLock: false,
        historyPatched: false,
        timerList: [],
        observers: [],
        routeToken: 0,
        startToken: 0
    };

    const CONFIG = {
        WIN_WIDTH: 420,
        WIN_HEIGHT: 560,
        MINI_WIDTH: 190,
        MINI_HEIGHT: 38,
        INIT_TOP: 80,
        INIT_LEFT: 15,
        REFRESH_INTERVAL: 5000,
        SUCCESS_DEBOUNCE: 3000,
        MAX_LOG_COUNT: 200,
        INIT_TIMEOUT: 5000,
        RESOURCE_PANEL_WIDTH: 168,
        RESOURCE_MINI_HEIGHT: 30,
        RESOURCE_INIT_TOP: 130,
        RESOURCE_INIT_LEFT: 15,
        FAIL_EP_PAGE_SIZE: 20,
        TASK_PAGE_SIZE: 20,
        JOB_PAGE_SIZE: 10,
        EP_PAGE_SIZE: 10,
        DEBOUNCE_MS: 300,
        CONCURRENCY_LIMIT: 8,
        MAX_OPENED_EPS: 500
    };

    const API_BASE = "https://tgs-geniestudio.agibot.com";
    // 通知Flutter应用EP审核成功
    function notifyFlutter(episodeId) {
        try {
            fetch('http://localhost:19080/review-success', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ episodeId: episodeId, time: Date.now() }),
                mode: 'no-cors'
            }).catch(function() {});
        } catch (e) {}
    }
    const TODAY = new Date().toISOString().slice(0, 10);

    const STORAGE_KEY_STATS = "epCompleteStat";
    const STORAGE_KEY_FRAMES = "epTotalFrames_v2";
    const STORAGE_KEY_AUTO_OPEN = "agibotAutoOpen";
    const STORAGE_KEY_PAUSED = "agibotPaused_v2";
    const STORAGE_KEY_OPENED_EPS = "agibotOpenedEpisodes_v2";
    const STORAGE_KEY_REFRESH_INTERVAL = "agibotRefreshInterval";
    const STORAGE_KEY_SCREENER = "agibotScreener";
    const STORAGE_KEY_SHOW_ALL_JOBS = "agibotShowAllJobs";

    const PAGE = {
        isCheck: () => /\/episodes\/\d+\/check/.test(location.href),
        isTaskList: () => !PAGE.isCheck() && !PAGE.isPreview(),
        isPreview: () => /\/collection\/episode\/preview/.test(location.href),
        getTaskId: () => {
            const match = location.href.match(/\/tasks\/(\d+)\/jobs/);
            return match ? match[1] : null;
        }
    };

    const State = {
        panelCreated: false,
        isMinimized: true,
        isPaused: false,
        currentTab: 'tasks',
        isRefreshing: false,
        logPool: [],
        lastSuccessTime: 0,
        checkMonitorActive: false,
        autoOpen: false,
        totalFrames: 0,
        initialized: false,
        resourcePanelCreated: false,
        refreshInterval: CONFIG.REFRESH_INTERVAL,
        resourcePanelMinimized: true,
        failedEps: [],
        failedEpsLoading: false,
        failedEpsLoaded: false,
        currentTaskEps: {},
        screener: '',
        showAllJobs: false,
        taskRefreshTimer: null,
        resources: []
    };

    var previewCache = {};

    let $ = {};

    // 全局拖拽状态
    let _dragging = false;
    let _offsetX = 0, _offsetY = 0;
    let _panelRef = null;
    let _isResourcePanel = false;
    let _moved = false;

    // 全局 mousedown 事件委托 - 同时处理主面板和资源面板的拖拽
    document.addEventListener('mousedown', function(e) {
        if (e.button !== 0) return;

        // 检查是否在资源面板头部
        var resourceHeader = e.target.closest('#' + RESOURCE_PANEL_ID + ' .resource-header');
        if (resourceHeader && !e.target.closest('.resource-btn')) {
            var resourcePanel = resourceHeader.closest('#' + RESOURCE_PANEL_ID);
            if (resourcePanel) {
                _offsetX = e.clientX - resourcePanel.offsetLeft;
                _offsetY = e.clientY - resourcePanel.offsetTop;
                _panelRef = resourcePanel;
                _isResourcePanel = true;
                _dragging = true;
                _moved = false;
                document.body.style.userSelect = "none";
                resourceHeader.style.cursor = "grabbing";
                e.preventDefault();
                return;
            }
        }

        // 检查是否在主面板头部
        var mainHeader = e.target.closest('#' + PANEL_ID + ' .panel-header');
        if (mainHeader && !e.target.closest('.act-btn')) {
            var mainPanel = mainHeader.closest('#' + PANEL_ID);
            if (mainPanel) {
                _offsetX = e.clientX - mainPanel.offsetLeft;
                _offsetY = e.clientY - mainPanel.offsetTop;
                _panelRef = mainPanel;
                _isResourcePanel = false;
                _dragging = true;
                _moved = false;
                document.body.style.userSelect = "none";
                mainHeader.style.cursor = "grabbing";
                e.preventDefault();
            }
        }
    });

    document.addEventListener('mousemove', function(e) {
        if (!_dragging || !_panelRef) return;

        _panelRef.style.left = (e.clientX - _offsetX) + 'px';
        _panelRef.style.top = (e.clientY - _offsetY) + 'px';
        _panelRef.style.right = 'auto';

        _moved = true;
    });

    document.addEventListener('mouseup', function() {
        if (!_dragging) return;

        _dragging = false;
        document.body.style.userSelect = "";

        if (_isResourcePanel) {
            var rh = _panelRef ? _panelRef.querySelector('.resource-header') : null;
            if (rh) rh.style.cursor = "move";
            if (State.resourcePanelMinimized && !_moved) toggleResourceMini();
        } else {
            var ph = _panelRef ? _panelRef.querySelector('.panel-header') : null;
            if (ph) ph.style.cursor = "move";
            if (State.isMinimized && !_moved) toggleMini();
        }

        _moved = false;
        _panelRef = null;
    });

    function toggleMini(e) {
        if (e) e.stopPropagation();
        State.isMinimized = !State.isMinimized;
        $.panel.classList.toggle('mini', State.isMinimized);
        $.minBtn.textContent = State.isMinimized ? '□' : '—';
    }

    const FRAMES_PER_SECOND = 30;

    function formatTime(frames, short) {
        var totalSeconds = Math.floor(frames / FRAMES_PER_SECOND);
        var h = Math.floor(totalSeconds / 3600);
        var m = Math.floor((totalSeconds % 3600) / 60);
        var s = totalSeconds % 60;
        if (short) {
            if (h > 0) return h + 'h' + m + 'm';
            if (m > 0) return m + 'm' + s + 's';
            return s + 's';
        }
        if (h > 0) return h + '小时' + m + '分' + s + '秒';
        if (m > 0) return m + '分' + s + '秒';
        return s + '秒';
    }

    function formatTimeShort(frames) {
        return formatTime(frames, true);
    }

    function waitForBody(timeout) {
        timeout = timeout || CONFIG.INIT_TIMEOUT;
        return new Promise((resolve, reject) => {
            if (document.body) { resolve(); return; }
            const observer = new MutationObserver(() => {
                if (document.body) { observer.disconnect(); resolve(); }
            });
            INSTANCE.observers.push(observer);
            observer.observe(document.documentElement, { childList: true, subtree: true });
            const timer = setTimeout(() => {
                observer.disconnect();
                INSTANCE.observers = INSTANCE.observers.filter(function(o) { return o !== observer; });
                if (document.body) resolve();
                else reject(new Error('等待body超时'));
            }, timeout);
            INSTANCE.timerList.push(timer);
        });
    }

    function safeEncode(str) {
        if (str === null || str === undefined) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    function isAlive(el) {
        if (!el || !el.parentNode) return false;
        try {
            return el.isConnected === undefined ? !!document.contains(el) : !!el.isConnected;
        } catch (e) {
            return !!document.contains(el);
        }
    }

    function runConcurrent(items, fn, limit) {
        var results = [];
        var index = 0;
        var active = 0;
        var completed = 0;
        var total = items.length;

        return new Promise(function(resolve) {
            if (total === 0) { resolve(results); return; }

            function scheduleNext() {
                while (active < limit && index < total) {
                    var currentIdx = index;
                    var item = items[currentIdx];
                    index++;
                    active++;

                    fn(item, currentIdx).then(function(result) {
                        results[currentIdx] = result;
                    }).catch(function(err) {
                        console.warn('[Agibot Monitor] Concurrent task #' + currentIdx + ' failed:', err);
                        results[currentIdx] = null;
                    }).then(function() {
                        active--;
                        completed++;
                        if (completed >= total) {
                            resolve(results);
                        } else {
                            scheduleNext();
                        }
                    });
                }
            }

            scheduleNext();
        });
    }

    function safeRemovePanel() {
        document.querySelectorAll("#" + PANEL_ID).forEach(function(panel) {
            try { if (panel.parentNode) panel.remove(); } catch (e) {}
        });
        State.panelCreated = false;
        INSTANCE.panelCreated = false;
        $ = {};
    }

    function safeGM(fn, fallback) {
        try { return fn(); } catch (e) { return fallback; }
    }

    var Store = {
        getStats: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_STATS, {}); }, {}); },
        setStats: function(s) { safeGM(function() { GM_setValue(STORAGE_KEY_STATS, s); }); },
        getFrames: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_FRAMES, {}); }, {}); },
        setFrames: function(f) { safeGM(function() { GM_setValue(STORAGE_KEY_FRAMES, f); }); },
        getAutoOpen: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_AUTO_OPEN, false); }, false); },
        setAutoOpen: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_AUTO_OPEN, v); }); },
        getPaused: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_PAUSED, false); }, false); },
        setPaused: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_PAUSED, v); }); },
        getRefreshInterval: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_REFRESH_INTERVAL, CONFIG.REFRESH_INTERVAL); }, CONFIG.REFRESH_INTERVAL); },
        setRefreshInterval: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_REFRESH_INTERVAL, v); }); },
        getScreener: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_SCREENER, ''); }, ''); },
        setScreener: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_SCREENER, v); }); },
        getShowAllJobs: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_SHOW_ALL_JOBS, false); }, false); },
        setShowAllJobs: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_SHOW_ALL_JOBS, v); }); },
        getOpenedEps: function() { return safeGM(function() { return GM_getValue(STORAGE_KEY_OPENED_EPS, {}); }, {}); },
        setOpenedEps: function(v) { safeGM(function() { GM_setValue(STORAGE_KEY_OPENED_EPS, v); }); },
        markEpOpened: function(epKey) {
            var opened = Store.getOpenedEps();
            opened[epKey] = Date.now();
            var keys = Object.keys(opened);
            if (keys.length > CONFIG.MAX_OPENED_EPS) {
                keys.sort(function(a, b) { return opened[a] - opened[b]; });
                keys.slice(0, keys.length - CONFIG.MAX_OPENED_EPS).forEach(function(k) { delete opened[k]; });
            }
            Store.setOpenedEps(opened);
        },
        isEpOpened: function(epKey) {
            var opened = Store.getOpenedEps();
            var ts = opened[epKey];
            if (!ts) return false;
            return new Date(ts).toISOString().slice(0, 10) === TODAY;
        },
        cleanOldEps: function() {
            var opened = Store.getOpenedEps();
            var changed = false;
            Object.keys(opened).forEach(function(k) {
                if (new Date(opened[k]).toISOString().slice(0, 10) !== TODAY) {
                    delete opened[k];
                    changed = true;
                }
            });
            if (changed) Store.setOpenedEps(opened);
        },
        getTodayFrames: function() {
            var frames = Store.getFrames();
            return frames[TODAY] || 0;
        },
        addFrames: function(framesToAdd) {
            if (!framesToAdd || framesToAdd <= 0) return;
            var frames = Store.getFrames();
            frames[TODAY] = (frames[TODAY] || 0) + framesToAdd;
            Store.setFrames(frames);
            State.totalFrames = frames[TODAY];
        }
    };

    var Log = {
        lastLog: '',
        lastLogTime: 0,
        add: function(msg, type) {
            type = type || 'info';
            var now = Date.now();
            if (msg === Log.lastLog && now - Log.lastLogTime < 5000) return;
            if (type === 'auto' && now - Log.lastLogTime < 2000) return;
            Log.lastLog = msg;
            Log.lastLogTime = now;
            var entry = { time: new Date().toLocaleTimeString('zh-CN', { hour12: false }), msg: msg, type: type };
            State.logPool.push(entry);
            if (State.logPool.length > CONFIG.MAX_LOG_COUNT) State.logPool.shift();
            Log.render();
        },
        render: function() {
            if (!isAlive($.logBody)) return;
            if (!State.logPool.length) {
                $.logBody.innerHTML = '<div class="log-empty">暂无日志</div>';
                return;
            }
            var html = '';
            var logs = State.logPool.slice(-80);
            for (var i = 0; i < logs.length; i++) {
                var item = logs[i];
                var cls = { info: 'c-info', success: 'c-success', error: 'c-error', warn: 'c-warn', auto: 'c-auto', pause: 'c-pause' }[item.type] || 'c-info';
                html += '<div class="log-line ' + cls + '"><span class="log-time">' + item.time + '</span><span class="log-content">' + item.msg + '</span></div>';
            }
            $.logBody.innerHTML = html;
            $.logBody.scrollTop = $.logBody.scrollHeight;
        },
        clear: function() {
            State.logPool = [];
            Log.render();
            Log.add('日志已清空');
        }
    };

    var Stats = {
        today: function() { return (Store.getStats()[TODAY] || 0); },
        todayFrames: function() { return Store.getTodayFrames(); },
        add: function() {
            var now = Date.now();
            if (now - State.lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;
            State.lastSuccessTime = now;
            var s = Store.getStats();
            s[TODAY] = (s[TODAY] || 0) + 1;
            Store.setStats(s);
            var urlMatch = location.href.match(/episodes\/(\d+)\/check/);
            var episodeId = urlMatch ? parseInt(urlMatch[1]) : null;
            
            // 通知Flutter应用
            if (episodeId) {
                notifyFlutter(episodeId);
            }
            
            if (urlMatch) {
                API.fetchMaxFrames(urlMatch[1]).then(function(frames) {
                    if (frames > 0) {
                        Store.addFrames(frames);
                        Stats.render();
                    } else {
                        Stats.render();
                    }
                }).catch(function() {
                    Stats.render();
                });
            } else {
                Stats.render();
            }
        },
        reset: function() {
            if (!confirm('确认重置今日统计（包含视频时长）？')) return;
            var s = Store.getStats();
            s[TODAY] = 0;
            Store.setStats(s);
            var frames = Store.getFrames();
            frames[TODAY] = 0;
            Store.setFrames(frames);
            State.totalFrames = 0;
            Stats.render();
            Log.add('今日统计已重置（含视频时长）', 'warn');
        },
        render: function() {
            var todayFrames = Store.getTodayFrames();
            var timeStr = formatTime(todayFrames);
            if (isAlive($.statBadge)) $.statBadge.textContent = '完成 ' + Stats.today();
            if (isAlive($.timeBadge)) $.timeBadge.textContent = formatTimeShort(todayFrames);
            if (isAlive($.statFooter)) $.statFooter.textContent = '今日完成: ' + Stats.today() + ' | 时长: ' + timeStr;
            if (isAlive($.resetBtn)) $.resetBtn.textContent = Stats.today() + '条 | ' + formatTimeShort(todayFrames) + ' | 重置';
            
            // 同步更新页头统计
            var statsEl = document.getElementById('agibot-header-stats');
            if (statsEl) {
                var countEl = statsEl.querySelector('.agibot-stat-count');
                var timeEl = statsEl.querySelector('.agibot-stat-time');
                if (countEl) countEl.textContent = Stats.today();
                if (timeEl) timeEl.textContent = formatTimeShort(todayFrames);
            }
        }
    };

    var API = {
        fetchMaxFrames: function(episodeId) {
            return new Promise(function(resolve) {
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: API_BASE + '/data/api/v1/collect/review/data/' + episodeId,
                    timeout: 5000,
                    onload: function(res) {
                        try { var data = JSON.parse(res.responseText); resolve(data && data.data && data.data.max ? data.data.max : 0); } catch (e) { resolve(0); }
                    },
                    onerror: function() { resolve(0); },
                    ontimeout: function() { resolve(0); }
                });
            });
        },

        fetchResources: function(taskId) {
            return new Promise(function(resolve) {
                if (!taskId || !window[SCRIPT_KEY]) { resolve([]); return; }
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: API_BASE + '/data/api/v1/collect/task/resource/all?task_id=' + taskId,
                    timeout: 8000,
                    onload: function(res) {
                        try {
                            var data = JSON.parse(res.responseText);
                            if (data.code === 0 && data.data && Array.isArray(data.data.list)) {
                                resolve(data.data.list.map(function(item) { return item.name; }).filter(Boolean));
                            } else { resolve([]); }
                        } catch (e) { resolve([]); }
                    },
                    onerror: function() { resolve([]); },
                    ontimeout: function() { resolve([]); }
                });
            });
        },

        fetchTaskPage: function(pageNum) {
            return new Promise(function(resolve) {
                if (INSTANCE.phase !== 'running') { resolve(null); return; }
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: API_BASE + '/data/api/v1/collect/tasks?page_num=' + pageNum + '&page_size=' + CONFIG.TASK_PAGE_SIZE,
                    timeout: 10000,
                    onload: function(res) {
                        try {
                            var json = JSON.parse(res.responseText);
                            if (json.code === 40101) { resolve({ code: 40101 }); return; }
                            if (json.code === 0 && json.data) {
                                resolve({ code: 0, list: json.data.list || [] });
                            } else { resolve(null); }
                        } catch (e) { resolve(null); }
                    },
                    onerror: function() { resolve(null); },
                    ontimeout: function() { resolve(null); }
                });
            });
        },

        fetchAllTasks: function() {
            if (INSTANCE.phase !== 'running' || !isAlive($.taskBody)) { State.isRefreshing = false; return; }

            function setLoading(text) {
                var loadingEl = $.taskBody.querySelector('.list-loading');
                if (loadingEl) {
                    loadingEl.textContent = text;
                } else {
                    loadingEl = document.createElement('div');
                    loadingEl.className = 'list-loading';
                    loadingEl.textContent = text;
                    $.taskBody.appendChild(loadingEl);
                }
            }

            $.taskBody.innerHTML = '';
            setLoading('加载任务列表...');
            State.isRefreshing = true;

            // 先获取第1页，确定是否需要加载更多
            API.fetchTaskPage(1).then(function(result) {
                if (!result) {
                    $.taskBody.innerHTML = '<div class="empty-text err">网络错误</div>';
                    Log.add('加载任务列表失败', 'error');
                    State.isRefreshing = false;
                    return;
                }
                if (result.code === 40101) {
                    $.taskBody.innerHTML = '<div class="empty-text err">登录失效，请刷新页面</div>';
                    Log.add('登录失效', 'error');
                    State.isRefreshing = false;
                    return;
                }

                var firstPageTasks = result.list || [];
                var allTasks = firstPageTasks.slice();

                // 第1页不满，说明只有1页
                if (firstPageTasks.length < CONFIG.TASK_PAGE_SIZE) {
                    var loadingEl = $.taskBody.querySelector('.list-loading');
                    if (loadingEl) loadingEl.remove();
                    API.renderTaskList(allTasks);
                    State.isRefreshing = false;
                    return;
                }

                // 第1页满，预估总页数并并发获取剩余页
                setLoading('加载任务列表... (1+?) 页');
                var maxEstimate = 20; // 预估最多20页（400条任务）
                var remainingPages = [];
                for (var p = 2; p <= maxEstimate; p++) {
                    remainingPages.push(p);
                }

                return runConcurrent(remainingPages, function(pageNum) {
                    if (INSTANCE.phase !== 'running') return [];
                    return API.fetchTaskPage(pageNum).then(function(res) {
                        return { page: pageNum, list: (res && res.list) || [], hasMore: res && res.list && res.list.length >= CONFIG.TASK_PAGE_SIZE };
                    });
                }, CONFIG.CONCURRENCY_LIMIT).then(function(results) {
                    // 按页码排序合并，遇到空页截断
                    var sorted = results.filter(Boolean).sort(function(a, b) { return a.page - b.page; });
                    for (var i = 0; i < sorted.length; i++) {
                        allTasks = allTasks.concat(sorted[i].list);
                        if (!sorted[i].hasMore) break;
                    }
                    var loadingEl = $.taskBody.querySelector('.list-loading');
                    if (loadingEl) loadingEl.remove();
                    API.renderTaskList(allTasks);
                    State.isRefreshing = false;
                });
            }).catch(function() {
                $.taskBody.innerHTML = '<div class="empty-text err">解析失败</div>';
                State.isRefreshing = false;
            });
        },

        renderTaskList: function(allTasks) {
            var total = 0;
            allTasks.forEach(function(t) { total += Number(t.not_check_count || 0); });
            if (isAlive($.countBadge)) $.countBadge.textContent = total + '待审';

            if (!allTasks.length) {
                if (!$.taskBody.querySelector('.empty-text')) {
                    $.taskBody.innerHTML = '<div class="empty-text">暂无任务</div>';
                }
                State.isRefreshing = false;
                return;
            }

            Log.add('加载完成：共 ' + allTasks.length + ' 个任务，' + total + ' 条待审核', 'info');

            // 获取现有任务行的Map
            var existingRows = {};
            $.taskBody.querySelectorAll('.task-row').forEach(function(row) {
                existingRows[row.dataset.tid] = row;
            });

            var existingIds = Object.keys(existingRows);
            var newIds = allTasks.map(function(t) { return String(t.id); });

            // 移除已不存在的任务
            existingIds.forEach(function(id) {
                if (newIds.indexOf(id) === -1 && existingRows[id]) {
                    existingRows[id].remove();
                    delete existingRows[id];
                }
            });

            // 按待审数量降序排列，任务量最大的在最前面
            allTasks.sort(function(a, b) {
                return Number(b.not_check_count || 0) - Number(a.not_check_count || 0);
            });

            // 更新或新增任务
            var pendingJobs = []; // 需要加载Jobs的任务
            allTasks.forEach(function(t) {
                var tid = String(t.id);
                var n = Number(t.not_check_count || 0);
                var name = safeEncode(t.name || '未命名');
                var existingRow = existingRows[tid];

                if (existingRow) {
                    // 更新现有行
                    var countSpan = existingRow.querySelector('.t-count');
                    var nameSpan = existingRow.querySelector('.t-name');
                    if (countSpan && countSpan.textContent !== String(n)) {
                        countSpan.textContent = n;
                        existingRow.dataset.count = n;
                    }
                    if (nameSpan && nameSpan.textContent !== name) {
                        nameSpan.textContent = name;
                        nameSpan.title = name;
                        existingRow.dataset.name = name;
                    }
                } else {
                    // 新增任务卡片
                    var newRow = document.createElement('div');
                    newRow.className = 'task-row task-row-new';
                    newRow.dataset.tid = tid;
                    newRow.dataset.name = name;
                    newRow.dataset.count = n;
                    newRow.innerHTML =
                        '<div class="task-card-header">' +
                            '<span class="t-id">' + t.id + '</span>' +
                            '<span class="t-name" title="' + name + '">' + name + '</span>' +
                            '<span class="t-count">' + n + '</span>' +
                        '</div>' +
                        '<div class="task-card-body">' +
                        '</div>';
                    
                    // 添加点击展开/折叠事件
                    var header = newRow.querySelector('.task-card-header');
                    var body = newRow.querySelector('.task-card-body');
                    if (header && body) {
                        header.addEventListener('click', function() {
                            body.classList.toggle('collapsed');
                        });
                    }
                    
                    existingRows[tid] = newRow;
                    pendingJobs.push({ tid: tid, name: name, container: newRow.querySelector('.task-card-body') });
                }
            });

            // 按排序后的顺序重排DOM节点（不重建，只移动位置）
            allTasks.forEach(function(t) {
                var tid = String(t.id);
                var row = existingRows[tid];
                if (row && row.parentNode === $.taskBody) {
                    $.taskBody.appendChild(row); // appendChild 会移动已有节点到末尾
                } else if (row) {
                    $.taskBody.appendChild(row); // 新节点插入
                }
            });

            // 加载新增任务的Jobs
            if (pendingJobs.length > 0) {
                setTimeout(function() {
                    if (INSTANCE.phase !== 'running') return;
                    pendingJobs.forEach(function(job) {
                        API.fetchJobs(job.tid, job.name, job.container);
                    });
                }, 200);
            }

            // 更新已有任务的Jobs（如果需要）
            var refreshExisting = State._refreshExistingJobs !== false;
            if (refreshExisting) {
                setTimeout(function() {
                    if (INSTANCE.phase !== 'running') return;
                    $.taskBody.querySelectorAll('.task-row').forEach(function(row) {
                        var tid = row.dataset.tid;
                        var isNew = row.classList.contains('task-row-new');
                        if (!isNew) {
                            var body = row.querySelector('.task-card-body');
                            var hasContent = body && (body.querySelector('.ep-container') || body.querySelector('.job-sort-container'));
                            if (!hasContent) {
                                API.fetchJobs(tid, row.dataset.name || '', body);
                            }
                        }
                    });
                    // 移除new标记
                    $.taskBody.querySelectorAll('.task-row-new').forEach(function(row) {
                        row.classList.remove('task-row-new');
                    });
                }, 200);
            }

            State.isRefreshing = false;
        },

        fetchTasks: function() {
            if (INSTANCE.phase !== 'running' || State.isRefreshing || State.isPaused || !isAlive($.taskBody)) return;
            State.isRefreshing = true;
            // 不再清空列表，只更新状态
            var existingEmpty = $.taskBody.querySelector('.empty-text');
            if (existingEmpty) {
                existingEmpty.remove();
            }
            API.fetchAllTasks();
        },

        fetchJobs: function(taskId, taskName, container) {
            if (INSTANCE.phase !== 'running' || !isAlive(container)) return;
            GM_xmlhttpRequest({
                method: 'GET',
                url: API_BASE + '/data/api/v1/collect/task/job?task_id=' + taskId + '&page_num=1&page_size=' + CONFIG.JOB_PAGE_SIZE,
                timeout: 8000,
                onload: function(res) {
                    if (INSTANCE.phase !== 'running') return;
                    try {
                        if (!isAlive(container)) return;
                        var json = JSON.parse(res.responseText);
                        if (json.code === 40101) { container.innerHTML = '<span class="no-ep err">失效</span>'; return; }
                        var jobs = (json.data && json.data.list) || [];
                        if (!jobs.length) { container.innerHTML = '<span class="no-ep">无Job</span>'; return; }
                        var ids = [];
                        jobs.forEach(function(j) {
                            if (Array.isArray(j.variables)) {
                                j.variables.forEach(function(v) {
                                    if (v.job_id) ids.push(v.job_id);
                                });
                            }
                        });
                        if (!ids.length) { container.innerHTML = '<span class="no-ep">无JobID</span>'; return; }
                        container.innerHTML = '';
                        
                        // 创建Job容器
                        var jobContainer = document.createElement('div');
                        jobContainer.className = 'job-sort-container';
                        container.appendChild(jobContainer);
                        
                        var pendingJobs = [];
                        var emptyJobs = [];
                        var completedCount = 0;
                        
                        ids.forEach(function(jid) {
                            var jobSection = document.createElement('div');
                            jobSection.className = 'job-section loading';
                            jobSection.dataset.jobId = jid;
                            jobContainer.appendChild(jobSection);
                            
                            API.fetchEps(taskId, jid, jobSection, function(hasEps, epCount) {
                                completedCount++;
                                if (hasEps) {
                                    pendingJobs.push({ jid: jid, count: epCount, section: jobSection });
                                } else {
                                    emptyJobs.push({ section: jobSection });
                                }
                                
                                // 所有 Job 都加载完成后排序
                                if (completedCount === ids.length) {
                                    jobContainer.innerHTML = '';
                                    // 有待审核EP的Job始终显示
                                    pendingJobs.forEach(function(j) {
                                        j.section.classList.remove('loading');
                                        j.section.classList.remove('no-eps');
                                        jobContainer.appendChild(j.section);
                                    });
                                    // 无待审核EP的Job：根据showAllJobs决定是否显示
                                    emptyJobs.forEach(function(j) {
                                        j.section.classList.remove('loading');
                                        if (State.showAllJobs) {
                                            // 显示所有Job，标记为无待审
                                            j.section.classList.add('no-eps');
                                            jobContainer.appendChild(j.section);
                                        } else {
                                            // 默认隐藏无待审EP的Job
                                            j.section.remove();
                                        }
                                    });
                                }
                            });
                        });
                    } catch (e) { console.error('[Agibot Monitor] 获取Jobs失败:', e); }
                }
            });
        },

        fetchEps: function(taskId, jobId, container, onComplete) {
            if (INSTANCE.phase !== 'running' || !isAlive(container)) {
                if (onComplete) onComplete(false, 0);
                return;
            }
            
            // 创建 Job 标题行
            var jobHeader = document.createElement('div');
            jobHeader.className = 'job-header';
            jobHeader.innerHTML = '<span class="job-label">Job ' + jobId + '</span>';
            
            // 创建首帧按钮
            var previewBtn = document.createElement('button');
            previewBtn.className = 'ep-preview-btn';
            previewBtn.textContent = '▶ 首帧';
            previewBtn.title = '查看第一帧（Job级别预览）';
            previewBtn.onclick = function(e) {
                e.stopPropagation();
                var origText = previewBtn.textContent;
                previewBtn.textContent = '打开中...';
                previewBtn.disabled = true;
                API.fetchPreviewUrl(taskId, jobId).then(function(previewUrl) {
                    previewBtn.textContent = origText;
                    previewBtn.disabled = false;
                    if (previewUrl) {
                        if (typeof GM_openInTab === 'function') {
                            GM_openInTab(previewUrl);
                        } else {
                            window.open(previewUrl, '_blank');
                        }
                    } else {
                        alert('获取预览链接失败，请检查任务是否有分配人员');
                    }
                });
            };
            jobHeader.appendChild(previewBtn);
            container.appendChild(jobHeader);
            
            // 创建 EP 按钮容器
            var epContainer = document.createElement('div');
            epContainer.className = 'ep-container';
            container.appendChild(epContainer);
            
            GM_xmlhttpRequest({
                method: 'GET',
                url: API_BASE + '/data/api/v1/collect/tasks/' + taskId + '/jobs/' + jobId + '/episodes?status%5B%5D=9&with_status_count=true&page_num=1&page_size=' + CONFIG.EP_PAGE_SIZE,
                timeout: 8000,
                onload: function(res) {
                    if (INSTANCE.phase !== 'running') return;
                    try {
                        if (!isAlive(container)) return;
                        var json = JSON.parse(res.responseText);
                        if (json.code === 40101) {
                            epContainer.innerHTML = '<span class="no-ep err">失效</span>';
                            if (onComplete) onComplete(false, 0);
                            return;
                        }
                        var eps = (json.data && json.data.list) || [];
                        if (!eps.length) {
                            epContainer.innerHTML = '<span class="no-ep">无待审核EP</span>';
                            if (onComplete) onComplete(false, 0);
                            return;
                        }

                        var newNormalEps = [];
                        var taskEpKey = 'task' + taskId;
                        if (!State.currentTaskEps[taskEpKey]) State.currentTaskEps[taskEpKey] = [];

                        eps.forEach(function(ep) {
                            if (!ep.id) return;
                            var url = API_BASE + '/data/collection/tasks/' + taskId + '/jobs/' + jobId + '/episodes/' + ep.id + '/check';
                            var epKey = 'task' + taskId + '-ep' + ep.id;
                            var alreadyOpened = Store.isEpOpened(epKey);
                            var isFail = API.isEpFailed(ep);

                            State.currentTaskEps[taskEpKey].push({
                                id: ep.id,
                                taskId: taskId,
                                jobId: jobId,
                                url: url,
                                key: epKey,
                                isFail: isFail,
                                opened: alreadyOpened
                            });

                            var btn = document.createElement('button');
                            btn.className = 'ep-btn';
                            if (isFail) btn.classList.add('ep-fail');
                            if (alreadyOpened) btn.classList.add('opened');
                            btn.textContent = 'EP' + ep.id;
                            if (isFail) btn.textContent += '(失败)';
                            btn.title = isFail ? 'EP' + ep.id + ' 验收失败' : (alreadyOpened ? 'EP' + ep.id + ' 今日已打开' : '打开 EP' + ep.id);
                            btn.onclick = function(e) {
                                e.stopPropagation();
                                window.open(url, '_blank');
                                Store.markEpOpened(epKey);
                                btn.classList.add('opened');
                            };
                            epContainer.appendChild(btn);

                            if (!alreadyOpened && !isFail) {
                                newNormalEps.push({ id: ep.id, url: url, key: epKey });
                            }
                        });

                        if (!State.isPaused && State.autoOpen && newNormalEps.length > 0) {
                            Log.add('自动打开 ' + newNormalEps.length + ' 个新普通EP（失败EP不自动打开）', 'auto');
                            newNormalEps.forEach(function(ep, idx) {
                                Store.markEpOpened(ep.key);
                                var timer = setTimeout(function() {
                                    if (!window[SCRIPT_KEY]) return;
                                    window.open(ep.url, '_blank');
                                    Log.add('  EP' + ep.id, 'auto');
                                }, idx * 400);
                                INSTANCE.timerList.push(timer);
                            });
                        }
                        
                        // 调用回调通知是否有待审核 EP
                        if (onComplete) onComplete(eps.length > 0, eps.length);
                    } catch (e) { 
                        console.error('[Agibot Monitor] 获取EPs失败:', e);
                        if (onComplete) onComplete(false, 0);
                    }
                },
                onerror: function() {
                    epContainer.innerHTML = '<span class="no-ep err">加载失败</span>';
                    if (onComplete) onComplete(false, 0);
                },
                ontimeout: function() {
                    epContainer.innerHTML = '<span class="no-ep err">超时</span>';
                    if (onComplete) onComplete(false, 0);
                }
            });
        },

        isEpFailed: function(ep) {
            // 对齐 Genie Studio isReworkEpisode：current_stage 必须是 screening/pending
            var cs = ep.current_stage;
            if (!cs || cs.stage_code !== 'screening' || cs.stage_status !== 'pending') {
                return false;
            }

            if (!Array.isArray(ep.stage_workflow) || ep.stage_workflow.length === 0) {
                return false;
            }
            var stages = ep.stage_workflow;

            // 从后往前找最后一次验收失败（reject）
            var lastRejectIdx = -1;
            for (var i = stages.length - 1; i >= 0; i--) {
                var s = stages[i];
                if (s.stage_code === 'acceptance' && s.stage_status === 'failed' && s.action === 'reject') {
                    lastRejectIdx = i;
                    break;
                }
            }
            if (lastRejectIdx === -1) return false;

            // 检查是否已返工（重新初筛成功、进入review阶段、或重新提交验收）
            for (var i = lastRejectIdx + 1; i < stages.length; i++) {
                var s = stages[i];
                if (s.stage_code === 'screening' && (s.stage_status === 'success' || s.action === 'review')) {
                    return false;
                }
                if (s.stage_code === 'acceptance' && s.action === 'transition') {
                    return false;
                }
            }

            // 自审排除：验收人（reject）和初筛人（screening）为同一人时不计为失败
            if (API.isSelfReview(ep, lastRejectIdx)) return false;

            // 未返工且非自审，视为验收失败
            return true;
        },

        isSelfReview: function(ep, rejectIdx) {
            if (!Array.isArray(ep.stage_workflow)) return false;
            var stages = ep.stage_workflow;

            // 如果未传 rejectIdx，先查找
            if (rejectIdx === undefined || rejectIdx === null) {
                rejectIdx = -1;
                for (var i = stages.length - 1; i >= 0; i--) {
                    if (stages[i].stage_code === 'acceptance' && stages[i].stage_status === 'failed' && stages[i].action === 'reject') {
                        rejectIdx = i;
                        break;
                    }
                }
                if (rejectIdx === -1) return false;
            }

            var rejectStage = stages[rejectIdx];
            var rejectOperator = (rejectStage.operator || '').toLowerCase();
            if (!rejectOperator) return false;

            // 检查 reject 之前所有 screening 的 operator，任一匹配即为自审
            for (var i = rejectIdx - 1; i >= 0; i--) {
                var s = stages[i];
                if (s.stage_code === 'screening' && s.stage_status === 'success') {
                    var screeningOperator = (s.operator || '').toLowerCase();
                    if (screeningOperator === rejectOperator) {
                        return true;
                    }
                }
            }
            return false;
        },

        isEpByScreener: function(ep, screener) {
            if (!screener) return true;
            if (!Array.isArray(ep.stage_workflow)) return true;
            var stages = ep.stage_workflow;
            var lastRejectIdx = -1;
            var i, s;
            for (i = stages.length - 1; i >= 0; i--) {
                s = stages[i];
                if (s.stage_code === 'acceptance' && s.stage_status === 'failed' && s.action === 'reject') {
                    lastRejectIdx = i;
                    break;
                }
            }
            if (lastRejectIdx === -1) return false;

            var screenerLower = screener.toLowerCase();
            for (i = lastRejectIdx - 1; i >= 0; i--) {
                s = stages[i];
                if (s.stage_code === 'screening' && s.stage_status === 'success') {
                    var operator = (s.operator || '').toLowerCase();
                    var operatorName = (s.operator_display_name || '').toLowerCase();
                    if (operator === screenerLower || operatorName === screenerLower ||
                        operator.indexOf(screenerLower) !== -1 || operatorName.indexOf(screenerLower) !== -1) {
                        return true;
                    }
                }
            }
            return false;
        },

        getFailReason: function(ep) {
            if (!Array.isArray(ep.stage_workflow) || ep.stage_workflow.length === 0) {
                return 'status=2';
            }
            var stages = ep.stage_workflow;
            for (var i = stages.length - 1; i >= 0; i--) {
                var s = stages[i];
                if (s.stage_code === 'acceptance' && s.stage_status === 'failed' && s.action === 'reject') {
                    return s.reason || '验收失败';
                }
            }
            return '验收失败';
        },

        updateFailProgress: function(percent, text) {
            var wrap = document.getElementById('failEpProgressWrap');
            var fill = document.getElementById('failEpProgressFill');
            var txt = document.getElementById('failEpProgressText');
            if (wrap) wrap.style.display = text ? '' : 'none';
            if (fill) fill.style.width = (percent || 0) + '%';
            if (txt) txt.textContent = text || '';
        },

        fetchFailedEpsFromAllTasks: function(isAutoRefresh) {
            if (State.failedEpsLoading) return;
            if (INSTANCE.phase !== 'running') return;

            State.failedEpsLoading = true;

            // 自动刷新时保留旧数据做增量更新，手动刷新时清空
            var prevFailedKeys = {};
            if (isAutoRefresh) {
                State.failedEps.forEach(function(ep) { prevFailedKeys[ep.key] = true; });
            } else {
                State.failedEps = [];
            }

            var container = isAlive($.failedEpBody) ? $.failedEpBody : null;
            if (container && !isAutoRefresh) {
                container.innerHTML = '<div class="loading-text">正在获取验收失败EP，请稍候...</div>';
            }

            var concurrency = CONFIG.CONCURRENCY_LIMIT;
            Log.add('开始获取验收失败EP（并发' + concurrency + '路）' + (State.screener ? '，初筛人筛选：' + State.screener : ''), 'info');
            if (!isAutoRefresh) API.updateFailProgress(0, '获取任务列表...');

            var taskCount = 0;
            var jobCount = 0;
            var savedTaskIds = [];

            API.fetchAllTasksForFailedEp().then(function(allTasks) {
                savedTaskIds = allTasks.map(function(t) { return t.id; });
                taskCount = savedTaskIds.length;
                Log.add('共 ' + taskCount + ' 个任务，并发获取Job列表...', 'info');
                if (!isAutoRefresh) API.updateFailProgress(10, '获取Job (' + taskCount + ' 任务)...');

                return runConcurrent(savedTaskIds, function(taskId) {
                    return API.fetchAllJobsForTask(taskId).then(function(jobs) {
                        return { taskId: taskId, jobs: jobs };
                    });
                }, concurrency);

            }).then(function(jobsResults) {
                var allJobSpecs = [];
                var skippedNoReject = 0;
                var totalJobs = 0;
                var seenJobIds = {};
                jobsResults.forEach(function(result) {
                    if (!result || !result.jobs) return;
                    var taskId = result.taskId;
                    result.jobs.forEach(function(j) {
                        totalJobs++;
                        // 利用Job自带的review_result_count过滤：无拒审EP的Job直接跳过
                        var unapproved = (j.review_result_count && j.review_result_count.unapproved_cnt) || 0;
                        if (unapproved <= 0) {
                            skippedNoReject++;
                            return;
                        }

                        if (j.id && !seenJobIds[j.id]) {
                            allJobSpecs.push({ taskId: taskId, jobId: j.id, expectedFail: unapproved });
                            seenJobIds[j.id] = true;
                        }
                        if (Array.isArray(j.variables) && j.variables.length > 0) {
                            j.variables.forEach(function(v) {
                                if (v.job_id && !seenJobIds[v.job_id]) {
                                    allJobSpecs.push({ taskId: taskId, jobId: v.job_id, expectedFail: unapproved });
                                    seenJobIds[v.job_id] = true;
                                }
                            });
                        }
                    });
                });
                jobCount = allJobSpecs.length;
                Log.add('共 ' + totalJobs + ' 个Job，跳过 ' + skippedNoReject + ' 个无拒审Job，需获取 ' + jobCount + ' 个Job的EP', 'info');
                if (!isAutoRefresh) API.updateFailProgress(20, '获取EP (0/' + jobCount + ' Job)...');

                var epCompleted = 0;
                return runConcurrent(allJobSpecs, function(spec) {
                    return API.fetchAllEpsForJob(spec.taskId, spec.jobId).then(function(eps) {
                        epCompleted++;
                        if (!isAutoRefresh) {
                            var pct = 20 + Math.round((epCompleted / jobCount) * 75);
                            API.updateFailProgress(pct, '获取EP (' + epCompleted + '/' + jobCount + ' Job)...');
                        }
                        return { spec: spec, eps: eps };
                    });
                }, concurrency);

            }).then(function(epResults) {
                var screener = State.screener;
                var totalEps = 0;
                var failedEps = 0;
                var screenerFiltered = 0;
                var selfReviewExcluded = 0;

            var newFailedKeys = {}; // 本轮扫描发现的失败EP key

                epResults.forEach(function(result) {
                    if (!result || !result.eps) return;
                    var spec = result.spec;
                    result.eps.forEach(function(ep) {
                        totalEps++;

                        // 统计自审排除数（isEpFailed内部已排除，此处仅计数）
                        if (API.isSelfReview(ep)) selfReviewExcluded++;

                        if (API.isEpFailed(ep)) {
                            failedEps++;
                            if (API.isEpByScreener(ep, screener)) {
                                screenerFiltered++;
                                var epKey = 'task' + spec.taskId + '-ep' + ep.id;
                                newFailedKeys[epKey] = true;
                                // 自动刷新时跳过已存在的，避免重复
                                if (isAutoRefresh && prevFailedKeys[epKey]) return;
                                State.failedEps.push({
                                    id: ep.id,
                                    taskId: spec.taskId,
                                    jobId: spec.jobId,
                                    url: API_BASE + '/data/collection/tasks/' + spec.taskId + '/jobs/' + spec.jobId + '/episodes/' + ep.id + '/check',
                                    key: epKey,
                                    status: ep.status,
                                    stageWorkflow: ep.stage_workflow
                                });
                            }
                        }
                    });
                });

                // 自动刷新时：移除不再失败的EP（已返工或状态变化）
                if (isAutoRefresh) {
                    State.failedEps = State.failedEps.filter(function(ep) {
                        return newFailedKeys[ep.key];
                    });
                }

                var logMsg = 'EP扫描完成：共 ' + totalEps + ' 条EP，' + failedEps + ' 条验收失败';
                if (selfReviewExcluded > 0) {
                    logMsg += '（排除 ' + selfReviewExcluded + ' 条自审）';
                }
                logMsg += '，' + screenerFiltered + ' 条符合筛选';
                Log.add(logMsg, 'info');
                State.failedEpsLoading = false;
                State.failedEpsLoaded = true;
                if (!isAutoRefresh) API.updateFailProgress(100, '完成');
                setTimeout(function() { API.updateFailProgress(0, ''); }, 1500);
                API.renderFailedEps();
                Log.add('验收失败EP获取完成：扫描 ' + taskCount + ' 任务 / ' + jobCount + ' Job，发现 ' + State.failedEps.length + ' 条', 'success');
                var doneBtn = document.getElementById('getFailEpBtn');
                if (doneBtn) {
                    doneBtn.classList.remove('loading');
                    doneBtn.textContent = '重新获取验收失败EP';
                }
            }).catch(function(err) {
                State.failedEpsLoading = false;
                Log.add('获取验收失败EP失败: ' + (err && err.message ? err.message : err), 'error');
                if (container) {
                    container.innerHTML = '<div class="empty-text err">获取失败，请重试</div>';
                }
            });
        },

        fetchAllTasksForFailedEp: function() {
            return new Promise(function(resolve, reject) {
                var allTasks = [];
                var pageNum = 1;

                function fetchPage() {
                    GM_xmlhttpRequest({
                        method: 'GET',
                        url: API_BASE + '/data/api/v1/collect/tasks?page_num=' + pageNum + '&page_size=' + CONFIG.TASK_PAGE_SIZE,
                        timeout: 10000,
                        onload: function(res) {
                            try {
                                var json = JSON.parse(res.responseText);
                                if (json.code === 40101) { reject(new Error('登录失效')); return; }
                                if (json.code === 0 && json.data) {
                                    var list = json.data.list || [];
                                    allTasks = allTasks.concat(list);
                                    if (list.length < CONFIG.TASK_PAGE_SIZE) {
                                        resolve(allTasks);
                                    } else {
                                        pageNum++;
                                        setTimeout(fetchPage, 200);
                                    }
                                } else {
                                    resolve(allTasks);
                                }
                            } catch (e) { reject(e); }
                        },
                        onerror: function() { resolve(allTasks); },
                        ontimeout: function() { resolve(allTasks); }
                    });
                }
                fetchPage();
            });
        },

        fetchAllJobsForTask: function(taskId) {
            return new Promise(function(resolve) {
                var allJobs = [];
                var pageNum = 1;

                function fetchPage() {
                    GM_xmlhttpRequest({
                        method: 'GET',
                        url: API_BASE + '/data/api/v1/collect/task/job?task_id=' + taskId + '&page_num=' + pageNum + '&page_size=' + CONFIG.JOB_PAGE_SIZE,
                        timeout: 8000,
                        onload: function(res) {
                            try {
                                var json = JSON.parse(res.responseText);
                                if (json.code === 40101) { resolve([]); return; }
                                var jobs = (json.data && json.data.list) || [];
                                allJobs = allJobs.concat(jobs);
                                if (jobs.length < CONFIG.JOB_PAGE_SIZE) {
                                    resolve(allJobs);
                                } else {
                                    pageNum++;
                                    fetchPage();
                                }
                            } catch (e) { resolve(allJobs); }
                        },
                        onerror: function() { resolve(allJobs); },
                        ontimeout: function() { resolve(allJobs); }
                    });
                }
                fetchPage();
            });
        },

        fetchAllEpsForJob: function(taskId, jobId) {
            return new Promise(function(resolve) {
                var allEps = [];
                var pageNum = 1;

                function fetchPage() {
                    GM_xmlhttpRequest({
                        method: 'GET',
                        url: API_BASE + '/data/api/v1/collect/tasks/' + taskId + '/jobs/' + jobId + '/episodes?with_status_count=true&page_num=' + pageNum + '&page_size=' + CONFIG.EP_PAGE_SIZE,
                        timeout: 8000,
                        onload: function(res) {
                            try {
                                var json = JSON.parse(res.responseText);
                                if (json.code === 40101) { resolve([]); return; }
                                var eps = (json.data && json.data.list) || [];
                                allEps = allEps.concat(eps);
                                if (eps.length < CONFIG.EP_PAGE_SIZE) {
                                    resolve(allEps);
                                } else {
                                    pageNum++;
                                    fetchPage();
                                }
                            } catch (e) { resolve(allEps); }
                        },
                        onerror: function() { resolve(allEps); },
                        ontimeout: function() { resolve(allEps); }
                    });
                }
                fetchPage();
            });
        },

        renderFailedEps: function() {
            if (!isAlive($.failedEpBody)) return;

            if (!State.failedEps.length) {
                $.failedEpBody.innerHTML = '<div class="empty-text">' +
                    (State.failedEpsLoading ? '扫描中...' : '暂无验收失败EP') +
                    '</div>';
                return;
            }

            var html = '<div class="failed-ep-summary">发现 ' + State.failedEps.length + ' 条验收失败EP</div>';
            html += '<div class="failed-ep-grid">';

            State.failedEps.forEach(function(ep) {
                html += '<div class="failed-ep-card" data-ep-key="' + safeEncode(ep.key) + '">' +
                    '<div class="failed-ep-info">' +
                    '<span class="failed-ep-id">T' + ep.taskId + '-J' + ep.jobId + '-EP' + ep.id + '</span>' +
                    '<span class="failed-ep-reason">' + safeEncode(API.getFailReason(ep)) + '</span>' +
                    '</div>' +
                    '<button class="failed-ep-btn" data-url="' + safeEncode(ep.url) + '" data-key="' + safeEncode(ep.key) + '">前往处理</button>' +
                    '</div>';
            });

            html += '</div>';
            $.failedEpBody.innerHTML = html;

            $.failedEpBody.querySelectorAll('.failed-ep-btn').forEach(function(btn) {
                btn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    window.open(btn.dataset.url, '_blank');
                });
            });

            updateFailTabBadge();
        },

        fetchPreviewUrl: function(taskId, jobId) {
            var cacheKey = taskId + '_' + jobId;
            if (previewCache[cacheKey]) return Promise.resolve(previewCache[cacheKey]);
            if (previewCache[cacheKey] === null) return Promise.resolve(null);
            
            return new Promise(function(resolve) {
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: API_BASE + '/data/api/v1/collect/task/job/assignment/stat?job_id=' + jobId + '&page_num=1&page_size=10',
                    timeout: 5000,
                    onload: function(res) {
                        try {
                            var data = JSON.parse(res.responseText);
                            var assignments = (data.data && data.data.list) || [];
                            if (assignments.length > 0) {
                                var first = assignments[0];
                                if (first.assignment_id && first.display_name) {
                                    var url = API_BASE + '/data/collection/episode/preview?assignmentId=' + 
                                             first.assignment_id + '&taskId=' + taskId + 
                                             '&collectorName=' + encodeURIComponent(first.display_name) + 
                                             '&jobId=' + jobId;
                                    previewCache[cacheKey] = url;
                                    resolve(url);
                                    return;
                                }
                            }
                            previewCache[cacheKey] = null;
                            resolve(null);
                        } catch(e) {
                            previewCache[cacheKey] = null;
                            resolve(null);
                        }
                    },
                    onerror: function() {
                        previewCache[cacheKey] = null;
                        resolve(null);
                    },
                    ontimeout: function() {
                        previewCache[cacheKey] = null;
                        resolve(null);
                    }
                });
            });
        }
    };

    function renderConfig() {
        if (!isAlive($.configBody)) return;
        var intervalSeconds = State.refreshInterval > 0 ? Math.floor(State.refreshInterval / 1000) : 0;
        $.configBody.innerHTML =
            '<div class="config-section">' +
                '<div class="config-title">刷新设置</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">刷新频率</div>' +
                        '<div class="config-desc">设置任务列表自动刷新间隔（秒）</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<input type="number" class="config-input" id="refreshIntervalInput" min="0" max="600" value="' + intervalSeconds + '" placeholder="0">' +
                        '<span class="config-status">秒</span>' +
                    '</div>' +
                '</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">暂停刷新</div>' +
                        '<div class="config-desc">暂停自动刷新，其他功能不受影响</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<div class="config-switch' + (State.isPaused ? ' active' : '') + '" id="pauseSwitch"></div>' +
                        '<span class="config-status">' + (State.isPaused ? '已暂停' : '运行中') + '</span>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="config-section">' +
                '<div class="config-title">自动打开</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">自动打开新EP</div>' +
                        '<div class="config-desc">仅自动打开未打开、非验收失败的普通EP</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<div class="config-switch' + (State.autoOpen ? ' active' : '') + '" id="autoOpenSwitch"></div>' +
                        '<span class="config-status">' + (State.autoOpen ? '已开启' : '已关闭') + '</span>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="config-section">' +
                '<div class="config-title">验收失败筛选</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">初筛人</div>' +
                        '<div class="config-desc">只显示由该初筛人处理的验收失败EP（填写初筛人用户名，如 zhoujun）</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<input type="text" class="config-input" id="screenerInput" value="' + State.screener + '" placeholder="留空=显示全部">' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="config-section">' +
                '<div class="config-title">列表显示</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">显示所有Job的首帧</div>' +
                        '<div class="config-desc">关闭时只显示有待审核EP的Job，开启时显示所有Job（含首帧预览）</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<div class="config-switch' + (State.showAllJobs ? ' active' : '') + '" id="showAllJobsSwitch"></div>' +
                        '<span class="config-status">' + (State.showAllJobs ? '已开启' : '已关闭') + '</span>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="config-section">' +
                '<div class="config-title">统计与日志</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">重置今日统计</div>' +
                        '<div class="config-desc">重置今日完成数和视频时长统计</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<button class="config-btn" id="resetStatsBtn">重置</button>' +
                    '</div>' +
                '</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">清空日志</div>' +
                        '<div class="config-desc">清空所有日志记录</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<button class="config-btn" id="clearLogsBtn">清空</button>' +
                    '</div>' +
                '</div>' +
                '<div class="config-item">' +
                    '<div>' +
                        '<div class="config-label">重新获取验收失败EP</div>' +
                        '<div class="config-desc">清空缓存并重新扫描所有任务</div>' +
                    '</div>' +
                    '<div class="config-right">' +
                        '<button class="config-btn danger" id="refetchFailEpBtn">重新扫描</button>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="config-section">' +
                '<div class="config-item" style="justify-content:flex-end;">' +
                    '<button class="config-btn" id="saveConfigBtn" style="padding:8px 20px;font-size:12px;">保存配置</button>' +
                '</div>' +
            '</div>';
        bindConfigEvents();
    }

    function addStyles() {
        var styleId = PANEL_ID + "-styles";
        if (document.getElementById(styleId)) return;
        GM_addStyle([
            ':root{',
            '--text-1:#1e293b;',
            '--text-2:#475569;',
            '--text-3:#64748b;',
            '--text-4:#94a3b8;',
            '--text-light:#f8fafc;',
            '--accent:#059669;',
            '--accent-hover:#047857;',
            '--danger:#ef4444;',
            '--danger-hover:#dc2626;',
            '--warn:#f59e0b;',
            '--info:#3b82f6;',
            '--header-bg:#0f172a;',
            '--panel-bg:#ffffff;',
            '--border:#e2e8f0;',
            '--border-light:#f1f5f9;',
            '--shadow:0 4px 12px rgba(0,0,0,0.1);',
            '--radius:12px;',
            '--radius-sm:6px;',
            '}',

            '#' + PANEL_ID + ',#' + RESOURCE_PANEL_ID + '{position:relative !important;}',

            '#' + PANEL_ID + '{',
            'position:fixed !important;',
            'width:' + CONFIG.WIN_WIDTH + 'px !important;',
            'height:' + CONFIG.WIN_HEIGHT + 'px !important;',
            'background:var(--panel-bg) !important;',
            'color:var(--text-1) !important;',
            'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif !important;',
            'font-size:12px !important;',
            'line-height:1.5 !important;',
            'border-radius:var(--radius) !important;',
            'box-shadow:var(--shadow) !important;',
            'border:1px solid var(--border) !important;',
            'z-index:999999 !important;',
            'display:flex !important;',
            'flex-direction:column !important;',
            'overflow:hidden !important;',
            'user-select:none !important;',
            '}',

            '#' + PANEL_ID + '.mini{',
            'width:' + CONFIG.MINI_WIDTH + 'px !important;',
            'height:' + CONFIG.MINI_HEIGHT + 'px !important;',
            'border-radius:' + (CONFIG.MINI_HEIGHT / 2) + 'px !important;',
            '}',
            '#' + PANEL_ID + '.mini .panel-body,',
            '#' + PANEL_ID + '.mini .panel-footer,',
            '#' + PANEL_ID + '.mini .panel-tabs{display:none !important;}',

            '.panel-header{',
            'height:' + CONFIG.MINI_HEIGHT + 'px !important;',
            'min-height:' + CONFIG.MINI_HEIGHT + 'px !important;',
            'display:flex !important;',
            'align-items:center !important;',
            'padding:0 14px !important;',
            'background:var(--header-bg) !important;',
            'color:var(--text-light) !important;',
            'flex-shrink:0 !important;',
            'cursor:move !important;',
            'gap:10px !important;',
            '}',
            '.panel-header:active{cursor:grabbing !important;}',
            '.panel-header .title{',
            'font-weight:600 !important;font-size:13px !important;',
            'flex:1 !important;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;',
            '}',
            '.panel-header .badges{display:flex;gap:4px;flex-shrink:0;font-size:10px;}',
            '.panel-header .badge{',
            'background:rgba(255,255,255,0.1);padding:2px 6px;border-radius:4px;',
            'font-weight:500;',
            '}',
            '.panel-header .actions{display:flex;gap:4px;flex-shrink:0;}',
            '.act-btn{',
            'width:24px;height:24px;line-height:24px;text-align:center;',
            'border:none;background:rgba(255,255,255,0.1);color:var(--text-light);border-radius:4px;',
            'cursor:pointer;font-size:12px;',
            '}',
            '.act-btn:hover{background:rgba(255,255,255,0.2);}',
            '#closeBtn:hover{background:var(--danger);}',

            '.panel-tabs{',
            'display:flex;background:var(--border-light);',
            'flex-shrink:0;padding:4px;gap:2px;',
            '}',
            '.panel-tab{',
            'flex:1;padding:5px 6px;text-align:center;cursor:pointer;',
            'font-size:11px;font-weight:500;color:var(--text-3);',
            'border-radius:4px;',
            '}',
            '.panel-tab:hover{color:var(--text-1);}',
            '.panel-tab.active{color:var(--text-1);background:var(--panel-bg);font-weight:600;}',
            '.panel-tab .tab-badge{display:inline-block;background:var(--danger);color:white;border-radius:4px;padding:0 4px;font-size:9px;margin-left:2px;}',

            '.panel-body{flex:1;overflow-y:auto;min-height:0;}',
            '.panel-body::-webkit-scrollbar{width:6px;}',
            '.panel-body::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px;}',

            '.tab-content{padding:4px;}',

            '.task-row{',
            'margin-bottom:8px;border:1px solid var(--border);',
            'border-radius:var(--radius-sm);overflow:hidden;background:var(--panel-bg);',
            '}',
            '.task-row-new{animation:taskRowAppear 0.3s ease-out;}',
            '@keyframes taskRowAppear{',
            'from{opacity:0;}',
            'to{opacity:1;}',
            '}',
            '.task-card-header{',
            'display:flex;align-items:center;gap:8px;',
            'padding:8px 10px;background:var(--border-light);',
            'cursor:pointer;user-select:none;',
            '}',
            '.task-card-header:hover{background:var(--border);}',
            '.t-id{',
            'color:var(--text-3);font-weight:600;font-size:11px;',
            'padding:2px 6px;background:var(--panel-bg);',
            'border-radius:3px;flex-shrink:0;',
            '}',
            '.t-name{',
            'color:var(--text-1);font-weight:500;font-size:12px;',
            'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;',
            '}',
            '.t-count{',
            'color:var(--danger);font-weight:700;font-size:12px;',
            'padding:2px 8px;background:var(--panel-bg);',
            'border-radius:3px;flex-shrink:0;',
            '}',
            '.task-card-body{',
            'padding:4px;background:var(--panel-bg);',
            '}',
            '.task-card-body.collapsed{display:none;}',

            '.ep-btn{',
            'padding:3px 8px;font-size:11px;border:none;border-radius:4px;',
            'background:var(--info);color:white;cursor:pointer;margin:1px;',
            'font-weight:500;display:inline-block;',
            '}',
            '.ep-btn:hover{opacity:0.85;}',
            '.ep-btn.ep-fail{background:var(--danger) !important;}',
            '.ep-btn.opened{background:var(--text-4) !important;}',

            '.ep-preview-btn{',
            'padding:3px 8px;font-size:11px;border:1px solid var(--accent);border-radius:4px;',
            'background:transparent;color:var(--accent);cursor:pointer;margin:1px;',
            'font-weight:500;',
            '}',
            '.ep-preview-btn:hover{background:var(--accent);color:white;}',
            '.ep-preview-btn:disabled{opacity:0.5;cursor:not-allowed;}',

            '.job-sort-container{display:flex;flex-direction:column;gap:4px;}',
            '.job-section{',
            'border:1px solid var(--border);border-radius:4px;',
            'padding:4px 6px;background:var(--border-light);',
            '}',
            '.job-section.loading{opacity:0.6;}',
            '.job-section.no-eps{opacity:0.7;}',
            '.job-section.no-eps .job-label{color:var(--text-3);}',
            '.job-section.no-eps .ep-container::before{',
            'content:"无待审";font-size:10px;color:var(--text-4);margin-right:4px;}',
            '.job-header{',
            'display:flex;align-items:center;justify-content:space-between;',
            'margin-bottom:3px;',
            '}',
            '.job-label{',
            'font-size:10px;font-weight:600;color:var(--text-3);',
            '}',
            '.ep-container{',
            'display:flex;flex-wrap:wrap;gap:1px;',
            '}',

            '.no-ep{font-size:11px;color:var(--text-4);}',
            '.no-ep.err{color:var(--danger);}',
            '.loading-text,.empty-text{text-align:center;color:var(--text-4);padding:32px 16px;font-size:12px;}',
            '.list-loading{text-align:center;color:var(--text-4);padding:8px;font-size:11px;margin-top:4px;}',
            '.empty-text.err{color:var(--danger);}',
            '.ep-link-btn{',
            'display:inline-block;margin-left:6px;padding:1px 6px;font-size:10px;',
            'background:var(--accent);color:white !important;text-decoration:none !important;',
            'border-radius:3px;cursor:pointer;line-height:1.4;',
            '}',
            '.ep-link-btn:hover{background:var(--accent-hover);opacity:0.9;}',

            /* 右侧面板统计 - 紧凑无背景 */
            '.agibot-header-stats{',
            'display:inline-flex;align-items:center;gap:3px;',
            'margin:0;padding:0 6px;height:28px;',
            'font-size:12px;line-height:1;',
            'flex-shrink:0;',
            '}',
            '.agibot-stat-label{color:#9ca3ab;font-size:11px;}',
            '.agibot-stat-value{color:#059669;font-weight:600;font-size:13px;}',
            '.agibot-stat-sep{color:#d1d5db;margin:0 1px;}',
            '.agibot-stat-time{color:#6366f1 !important;font-size:13px;}',

            /* 侧边栏资源列表 - 模仿导航栏样式 */
            '.agibot-menu-divider{',
            'list-style:none;height:1px;margin:8px 12px;',
            'background:linear-gradient(to right,transparent,#e5e7eb,transparent);',
            '}',
            '.agibot-menu-item{',
            'list-style:none;display:flex;align-items:center;gap:10px;',
            'padding:8px 16px;font-size:14px;color:#374151;',
            'cursor:default;user-select:none;',
            '}',
            '.agibot-menu-item:hover{background:#f3f4f6;}',
            '.agibot-menu-icon{',
            'width:20px;text-align:center;font-size:14px;flex-shrink:0;',
            '}',
            '.agibot-menu-text{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
            '.agibot-menu-arrow{',
            'color:#9ca3af;font-size:16px;font-weight:600;',
            '}',
            '.agibot-menu-section{',
            'font-weight:600;color:#111827;',
            'background:linear-gradient(90deg,#eff6ff,transparent);',
            'border-left:3px solid #3b82f6;',
            '}',
            '.agibot-menu-sub{',
            'font-size:13px;color:#6b7280;padding-left:36px;',
            '}',
            '.agibot-menu-empty{',
            'font-size:12px;color:#9ca3af;font-style:italic;padding-left:36px;',
            '}',

            '.failed-ep-summary{',
            'padding:6px 12px;border-bottom:1px solid var(--border);',
            'font-size:12px;font-weight:600;color:var(--danger);',
            '}',
            '.failed-ep-grid{padding:4px 8px;display:flex;flex-direction:column;gap:2px;}',
            '.failed-ep-card{',
            'display:flex;justify-content:space-between;align-items:center;',
            'padding:6px 10px;background:var(--border-light);',
            'border-radius:4px;',
            '}',
            '.failed-ep-card:hover{background:var(--border);}',
            '.failed-ep-info{display:flex;flex-direction:column;gap:2px;min-width:0;flex:1;}',
            '.failed-ep-id{font-size:11px;font-weight:600;color:var(--text-1);}',
            '.failed-ep-reason{font-size:10px;color:var(--danger);}',
            '.failed-ep-btn{',
            'padding:4px 10px;font-size:11px;border:none;border-radius:6px;',
            'background:var(--danger);color:white;cursor:pointer;font-weight:500;',
            'white-space:nowrap;flex-shrink:0;',
            '}',
            '.failed-ep-btn:hover{background:var(--danger-hover);}',

            '.fail-ep-toolbar{',
            'display:flex;align-items:center;gap:8px;padding:6px 8px;',
            'background:var(--border-light);border-radius:var(--radius-sm);margin:4px 8px;',
            '}',
            '.fail-ep-action-btn{',
            'padding:5px 14px;font-size:11px;border:none;border-radius:4px;',
            'background:var(--danger);color:white;cursor:pointer;font-weight:600;',
            'white-space:nowrap;flex-shrink:0;',
            '}',
            '.fail-ep-action-btn:hover{background:var(--danger-hover);}',
            '.fail-ep-action-btn.loading{opacity:0.6;cursor:not-allowed;}',
            '.fail-ep-progress-wrap{',
            'flex:1;display:flex;align-items:center;gap:6px;min-width:0;',
            '}',
            '.fail-ep-progress-bar{',
            'flex:1;height:6px;background:var(--border);border-radius:3px;overflow:hidden;min-width:60px;',
            '}',
            '.fail-ep-progress-fill{',
            'height:100%;width:0%;background:linear-gradient(90deg,var(--info),var(--accent));',
            'border-radius:3px;transition:width 0.3s ease;',
            '}',
            '.fail-ep-progress-text{',
            'font-size:10px;color:var(--text-3);white-space:nowrap;flex-shrink:0;',
            '}',

            '.log-body{padding:4px;background:var(--border-light);min-height:100%;box-sizing:border-box;}',
            '.log-empty{text-align:center;color:var(--text-4);padding:32px 16px;font-size:12px;}',
            '.log-line{display:flex;gap:6px;padding:3px 6px;font-size:11px;line-height:1.4;}',
            '.log-line:hover{background:rgba(0,0,0,0.03);}',
            '.log-time{color:var(--text-4);font-size:10px;flex-shrink:0;}',
            '.log-content{color:var(--text-2);word-break:break-word;}',
            '.c-success .log-content{color:var(--accent);}',
            '.c-error .log-content{color:var(--danger);}',
            '.c-warn .log-content{color:var(--warn);}',
            '.c-auto .log-content{color:var(--info);}',

            '.panel-footer{',
            'height:30px;min-height:30px;display:flex;align-items:center;',
            'padding:0 8px;background:var(--border-light);',
            'border-top:1px solid var(--border);',
            'font-size:11px;color:var(--text-3);flex-shrink:0;justify-content:space-between;gap:6px;',
            '}',
            '.footer-left,.footer-right{display:flex;align-items:center;gap:4px;}',
            '.footer-left{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
            '.footer-btn{',
            'cursor:pointer;font-size:10px;padding:2px 6px;border-radius:3px;',
            'border:1px solid var(--border);white-space:nowrap;font-weight:500;',
            'background:var(--panel-bg);color:var(--text-2);',
            '}',
            '.footer-btn:hover{background:var(--border-light);}',
            '.pause-btn{color:var(--danger);border-color:rgba(239,68,68,0.3);}',
            '.pause-btn.active{color:var(--accent);border-color:rgba(5,150,105,0.3);}',
            '.auto-open-btn{color:var(--info);border-color:rgba(59,130,246,0.3);}',
            '.auto-open-btn.active{background:rgba(59,130,246,0.1);}',
            '.stat-reset{color:var(--text-3);}',

            '#' + RESOURCE_PANEL_ID + '{',
            'position:fixed !important;',
            'width:' + CONFIG.RESOURCE_PANEL_WIDTH + 'px !important;',
            'background:var(--panel-bg) !important;',
            'color:var(--text-1) !important;',
            'font-family:-apple-system,BlinkMacSystemFont,sans-serif !important;',
            'font-size:11px !important;',
            'border-radius:var(--radius-sm) !important;',
            'box-shadow:var(--shadow) !important;',
            'border:1px solid var(--border) !important;',
            'z-index:999998 !important;',
            'display:flex !important;',
            'flex-direction:column !important;',
            'user-select:none !important;',
            '}',
            '#' + RESOURCE_PANEL_ID + ':not(.mini){height:auto !important;overflow:hidden !important;max-height:none !important;}',
            '#' + RESOURCE_PANEL_ID + '.mini{',
            'height:' + CONFIG.RESOURCE_MINI_HEIGHT + 'px !important;',
            'max-height:' + CONFIG.RESOURCE_MINI_HEIGHT + 'px !important;',
            'overflow:hidden !important;',
            'border-radius:' + (CONFIG.RESOURCE_MINI_HEIGHT / 2) + 'px !important;',
            '}',
            '#' + RESOURCE_PANEL_ID + '.mini .resource-body{display:none !important;}',

            '.resource-header{',
            'height:' + CONFIG.RESOURCE_MINI_HEIGHT + 'px !important;',
            'min-height:' + CONFIG.RESOURCE_MINI_HEIGHT + 'px !important;',
            'display:flex !important;',
            'align-items:center !important;',
            'padding:0 10px !important;',
            'background:var(--header-bg) !important;',
            'color:var(--text-light) !important;',
            'flex-shrink:0 !important;',
            'cursor:move !important;',
            'gap:6px !important;',
            'border-radius:' + (CONFIG.RESOURCE_MINI_HEIGHT / 2) + 'px !important;',
            '}',
            '.resource-header:active{cursor:grabbing !important;}',
            '.resource-header .title{',
            'font-weight:600 !important;font-size:11px !important;',
            'flex:1 !important;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;',
            '}',
            '.resource-actions{display:flex;gap:4px;}',
            '.resource-btn{',
            'width:20px;height:20px;line-height:20px;text-align:center;',
            'border:1px solid rgba(255,255,255,0.2);background:transparent;color:var(--text-light);border-radius:4px;',
            'cursor:pointer;font-size:12px;',
            '}',
            '.resource-btn:hover{background:rgba(255,255,255,0.1);}',
            '#resourceMinBtn:hover{background:var(--accent);border-color:var(--accent);}',
            '#resourceCloseBtn:hover{background:var(--danger);border-color:var(--danger);}',
            '.resource-body{padding:6px 8px;overflow:visible;}',
            '.resource-item{',
            'padding:4px 8px;margin-bottom:4px;background:var(--border-light);',
            'border-radius:4px;font-size:11px;color:var(--text-1);font-weight:500;',
            'border-left:3px solid var(--accent);line-height:1.4;',
            'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;',
            '}',
            '.resource-item:hover{background:var(--border);}',
            '.resource-item:last-child{margin-bottom:0;}',
            '.resource-empty{text-align:center;color:var(--text-4);padding:12px 8px;font-size:11px;}',

            '.config-body{padding:12px;}',
            '.config-section{margin-bottom:16px;}',
            '.config-title{font-size:12px;font-weight:600;color:var(--text-1);margin-bottom:10px;}',
            '.config-item{display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border-light);}',
            '.config-item:last-child{border-bottom:none;}',
            '.config-label{font-size:12px;color:var(--text-1);font-weight:500;}',
            '.config-desc{font-size:10px;color:var(--text-4);margin-top:2px;}',
            '.config-right{display:flex;align-items:center;gap:6px;}',
            '.config-input{',
            'width:70px;padding:4px 8px;border:1px solid var(--border);',
            'border-radius:4px;font-size:12px;color:var(--text-1);',
            'background:var(--panel-bg);text-align:center;outline:none;',
            '}',
            '.config-input:focus{border-color:var(--accent);}',
            '.config-input::-webkit-outer-spin-button,.config-input::-webkit-inner-spin-button{-webkit-appearance;margin:0;}',
            '.config-input[type=number]{-moz-appearance:textfield;}',
            '.config-btn{',
            'padding:5px 12px;font-size:11px;border:1px solid var(--border);border-radius:4px;',
            'background:var(--panel-bg);color:var(--info);cursor:pointer;font-weight:500;',
            '}',
            '.config-btn:hover{background:var(--border-light);}',
            '.config-btn.danger{color:var(--danger);}',
            '.config-switch{',
            'width:36px;height:20px;border-radius:10px;background:var(--border);',
            'cursor:pointer;position:relative;transition:background 0.2s;',
            '}',
            '.config-switch.active{background:var(--accent);}',
            '.config-switch::after{',
            'content:"";position:absolute;top:2px;left:2px;width:16px;height:16px;',
            'border-radius:50%;background:white;transition:left 0.2s;',
            '}',
            '.config-switch.active::after{left:18px;}',
            '.config-status{font-size:10px;color:var(--text-4);}',
        ].join('\n'));
    }

    function buildPanel() {
        if (!document.body) {
            console.warn('[Agibot Monitor] body未就绪，无法创建面板');
            return false;
        }

        var existing = document.getElementById(PANEL_ID);
        if (existing) {
            console.log('[Agibot Monitor] 面板已存在，复用现有面板');
            $ = {
                panel: existing,
                header: document.getElementById('panelHeader'),
                countBadge: document.getElementById('countBadge'),
                statBadge: document.getElementById('statBadge'),
                timeBadge: document.getElementById('timeBadge'),
                statFooter: document.getElementById('statFooter'),
                minBtn: document.getElementById('minBtn'),
                closeBtn: document.getElementById('closeBtn'),
                tabs: existing.querySelectorAll('.panel-tab'),
                taskBody: document.getElementById('taskBody'),
                failedEpBody: document.getElementById('failedEpBody'),
                getFailEpBtn: document.getElementById('getFailEpBtn'),
                logBody: document.getElementById('logBody'),
                configBody: document.getElementById('configBody'),
                resetBtn: document.getElementById('resetBtn'),
                clearLogBtn: document.getElementById('clearLogBtn'),
                autoOpenBtn: document.getElementById('autoOpenBtn'),
                pauseBtn: document.getElementById('pauseBtn'),
            };
            State.panelCreated = true;
            INSTANCE.panelCreated = true;
            // 恢复最小化状态
            if (State.isMinimized) existing.classList.add('mini');
            else existing.classList.remove('mini');
            if (State.isPaused) existing.classList.add('paused');
            else existing.classList.remove('paused');
            bindEvents();
            return true;
        }

        State.panelCreated = false;
        INSTANCE.panelCreated = false;
        $ = {};

        var panel = document.createElement('div');
        panel.id = PANEL_ID;
        panel.style.left = CONFIG.INIT_LEFT + "px";
        panel.style.top = CONFIG.INIT_TOP + "px";
        if (State.isPaused) panel.classList.add('paused');
        if (State.isMinimized) panel.classList.add('mini');

        var todayFrames = Store.getTodayFrames();
        var timeStr = formatTimeShort(todayFrames);
        var failCount = State.failedEpsLoaded ? State.failedEps.length : 0;

        panel.innerHTML =
            '<div class="panel-header" id="panelHeader">' +
                '<span class="title">Agibot任务监控' + (State.isPaused ? ' [已暂停]' : '') + '</span>' +
                '<span class="badges">' +
                    '<span class="badge" id="countBadge">...待审</span>' +
                    '<span class="badge" id="statBadge">完成 0</span>' +
                    '<span class="badge" id="timeBadge">' + timeStr + '</span>' +
                '</span>' +
                '<span class="actions">' +
                    '<span class="act-btn" id="minBtn" title="最小化">' + (State.isMinimized ? '□' : '—') + '</span>' +
                    '<span class="act-btn" id="closeBtn" title="关闭">✕</span>' +
                '</span>' +
            '</div>' +
            '<div class="panel-tabs">' +
                '<div class="panel-tab active" data-tab="tasks">待审核EP</div>' +
                '<div class="panel-tab" data-tab="failEps">' +
                    '验收失败EP' + (failCount > 0 ? '<span class="tab-badge">' + failCount + '</span>' : '') +
                '</div>' +
                '<div class="panel-tab" data-tab="log">日志</div>' +
                '<div class="panel-tab" data-tab="config">配置</div>' +
            '</div>' +
            '<div class="panel-body">' +
                '<div id="tab-tasks" class="tab-content" style="display:block;">' +
                    '<div id="taskBody"><div class="loading-text">加载全部任务、Job、EP中...</div></div>' +
                '</div>' +
                '<div id="tab-failEps" class="tab-content" style="display:none;">' +
                    '<div id="failEpTabContent">' +
                        '<div class="fail-ep-toolbar">' +
                            '<button class="fail-ep-action-btn" id="getFailEpBtn">获取验收失败EP</button>' +
                            '<div class="fail-ep-progress-wrap" id="failEpProgressWrap" style="display:none;">' +
                                '<div class="fail-ep-progress-bar"><div class="fail-ep-progress-fill" id="failEpProgressFill"></div></div>' +
                                '<span class="fail-ep-progress-text" id="failEpProgressText"></span>' +
                            '</div>' +
                        '</div>' +
                        '<div id="failedEpBody"><div class="empty-text">点击上方按钮获取验收失败EP列表</div></div>' +
                    '</div>' +
                '</div>' +
                '<div id="tab-log" class="tab-content" style="display:none;">' +
                    '<div class="log-body" id="logBody"><div class="log-empty">暂无日志</div></div>' +
                '</div>' +
                '<div id="tab-config" class="tab-content" style="display:none;">' +
                    '<div class="config-body" id="configBody"></div>' +
                '</div>' +
            '</div>' +
            '<div class="panel-footer">' +
                '<span class="footer-left">' +
                    '<span id="statFooter">今日完成: 0 | 时长: ' + formatTime(todayFrames) + '</span>' +
                '</span>' +
                '<span class="footer-right">' +
                    '<button class="footer-btn pause-btn' + (State.isPaused ? ' active' : '') + '" id="pauseBtn">' +
                        (State.isPaused ? '恢复' : '暂停') +
                    '</button>' +
                    '<button class="footer-btn auto-open-btn' + (State.autoOpen ? ' active' : '') + '" id="autoOpenBtn">' +
                        (State.autoOpen ? '自动开:开' : '自动开:关') +
                    '</button>' +
                    '<button class="footer-btn stat-reset" id="resetBtn">重置统计</button>' +
                    '<button class="footer-btn" id="clearLogBtn">清空日志</button>' +
                '</span>' +
            '</div>';

        document.body.appendChild(panel);

        $ = {
            panel: panel,
            header: document.getElementById('panelHeader'),
            countBadge: document.getElementById('countBadge'),
            statBadge: document.getElementById('statBadge'),
            timeBadge: document.getElementById('timeBadge'),
            statFooter: document.getElementById('statFooter'),
            minBtn: document.getElementById('minBtn'),
            closeBtn: document.getElementById('closeBtn'),
            tabs: panel.querySelectorAll('.panel-tab'),
            taskBody: document.getElementById('taskBody'),
            failedEpBody: document.getElementById('failedEpBody'),
            getFailEpBtn: document.getElementById('getFailEpBtn'),
            logBody: document.getElementById('logBody'),
            configBody: document.getElementById('configBody'),
            resetBtn: document.getElementById('resetBtn'),
            clearLogBtn: document.getElementById('clearLogBtn'),
            autoOpenBtn: document.getElementById('autoOpenBtn'),
            pauseBtn: document.getElementById('pauseBtn'),
        };

        renderConfig();
        State.panelCreated = true;
        INSTANCE.panelCreated = true;
        bindEvents();
        return true;
    }

    function safeRemoveResourcePanel() {
        document.querySelectorAll("#" + RESOURCE_PANEL_ID).forEach(function(panel) {
            try { if (panel.parentNode) panel.remove(); } catch (e) {}
        });
        State.resourcePanelCreated = false;
        State.resourcePanelMinimized = true;
        if ($.resourcePanel) $.resourcePanel = null;
        if ($.resourceHeader) $.resourceHeader = null;
        if ($.resourceBody) $.resourceBody = null;
    }

    function toggleResourceMini() {
        if (!isAlive($.resourcePanel)) return;
        State.resourcePanelMinimized = !State.resourcePanelMinimized;
        $.resourcePanel.classList.toggle('mini', State.resourcePanelMinimized);
        $.resourceMinBtn.textContent = State.resourcePanelMinimized ? '□' : '—';
    }

    function bindResourceEvents() {
        if (!$.resourceMinBtn || !$.resourceCloseBtn) return;
        if ($.resourcePanel && $.resourcePanel.dataset.bound === '1') return;
        if ($.resourcePanel) $.resourcePanel.dataset.bound = '1';
        $.resourceMinBtn.addEventListener('click', function(e) { e.stopPropagation(); toggleResourceMini(); });
        $.resourceCloseBtn.addEventListener('click', function(e) { e.stopPropagation(); safeRemoveResourcePanel(); });
        var rh = $.resourcePanel ? $.resourcePanel.querySelector('.resource-header') : null;
        if (rh) rh.addEventListener('dblclick', function(e) { if (!e.target.closest('.resource-btn')) toggleResourceMini(); });
    }

    function buildResourcePanel(resources) {
        if (!document.body) return false;
        
        var existing = document.getElementById(RESOURCE_PANEL_ID);
        if (existing) {
            // 面板已存在，更新内容
            var body = existing.querySelector('.resource-body');
            if (body) {
                body.innerHTML = resources.length > 0
                    ? resources.map(function(name) { return '<div class="resource-item">' + safeEncode(name) + '</div>'; }).join('')
                    : '<div class="resource-empty">暂无资源</div>';
            }
            $.resourcePanel = existing;
            $.resourceHeader = existing.querySelector('.resource-header');
            $.resourceBody = body;
            $.resourceMinBtn = existing.querySelector('#resourceMinBtn');
            $.resourceCloseBtn = existing.querySelector('#resourceCloseBtn');
            if ($.resourcePanel.dataset.bound !== '1') {
                bindResourceEvents();
            }
            console.log('[Agibot Monitor] 资源面板已更新');
            return true;
        }

        var panel = document.createElement('div');
        panel.id = RESOURCE_PANEL_ID;
        panel.style.left = CONFIG.RESOURCE_INIT_LEFT + "px";
        panel.style.top = CONFIG.RESOURCE_INIT_TOP + "px";
        if (State.resourcePanelMinimized) panel.classList.add('mini');

        var html = resources.length > 0
            ? resources.map(function(name) { return '<div class="resource-item">' + safeEncode(name) + '</div>'; }).join('')
            : '<div class="resource-empty">暂无资源</div>';

        panel.innerHTML =
            '<div class="resource-header" id="resourceHeader">' +
                '<span class="title">资源列表</span>' +
                '<span class="resource-actions">' +
                    '<span class="resource-btn" id="resourceMinBtn" title="最小化">' + (State.resourcePanelMinimized ? '□' : '—') + '</span>' +
                    '<span class="resource-btn" id="resourceCloseBtn" title="关闭">✕</span>' +
                '</span>' +
            '</div>' +
            '<div class="resource-body" id="resourceBody">' + html + '</div>';

        document.body.appendChild(panel);
        $.resourcePanel = panel;
        $.resourceHeader = document.getElementById('resourceHeader');
        $.resourceBody = document.getElementById('resourceBody');
        $.resourceMinBtn = document.getElementById('resourceMinBtn');
        $.resourceCloseBtn = document.getElementById('resourceCloseBtn');
        State.resourcePanelCreated = true;
        bindResourceEvents();
        return true;
    }

    function updatePauseUI() {
        if (!isAlive($.panel)) return;
        if (State.isPaused) {
            $.panel.classList.add('paused');
            $.header.querySelector('.title').textContent = 'Agibot任务监控 [已暂停]';
            $.pauseBtn.textContent = '恢复';
            $.pauseBtn.classList.add('active');
        } else {
            $.panel.classList.remove('paused');
            $.header.querySelector('.title').textContent = 'Agibot任务监控';
            $.pauseBtn.textContent = '暂停';
            $.pauseBtn.classList.remove('active');
            API.fetchTasks();
        }
        var pauseSwitch = document.getElementById('pauseSwitch');
        if (pauseSwitch) {
            pauseSwitch.classList.toggle('active', State.isPaused);
            pauseSwitch.nextElementSibling.textContent = State.isPaused ? '已暂停' : '运行中';
        }
    }

    function updateFailTabBadge() {
        var tab = document.querySelector('.panel-tab[data-tab="failEps"]');
        if (!tab) return;
        var count = State.failedEps.length;
        tab.innerHTML = '验收失败EP' + (count > 0 ? '<span class="tab-badge">' + count + '</span>' : '');
    }

    function bindEvents() {
        if (!$.panel || !$.tabs || !$.minBtn || !$.closeBtn || !$.header) {
            console.warn('[Agibot Monitor] DOM缺失，绑定事件失败');
            return;
        }

        if ($.panel.dataset.bound === '1') return;
        $.panel.dataset.bound = '1';

        $.tabs.forEach(function(tab) {
            tab.addEventListener('click', function(e) {
                e.stopPropagation();
                State.currentTab = tab.dataset.tab;
                $.tabs.forEach(function(t) { t.classList.remove('active'); });
                tab.classList.add('active');

                document.getElementById('tab-tasks').style.display = State.currentTab === 'tasks' ? 'block' : 'none';
                document.getElementById('tab-failEps').style.display = State.currentTab === 'failEps' ? 'block' : 'none';
                document.getElementById('tab-log').style.display = State.currentTab === 'log' ? 'block' : 'none';
                document.getElementById('tab-config').style.display = State.currentTab === 'config' ? 'block' : 'none';

                if (State.currentTab === 'log') {
                    Log.render();
                }
                if (State.currentTab === 'config') {
                    renderConfig();
                }
                if (State.currentTab === 'failEps') {
                    API.renderFailedEps();
                }
            });
        });

        $.minBtn.addEventListener('click', toggleMini);
        $.closeBtn.addEventListener('click', function(e) { e.stopPropagation(); fullCleanup(); INSTANCE.phase = 'idle'; });
        $.header.addEventListener('dblclick', function(e) { if (!e.target.closest('.act-btn')) toggleMini(e); });

        $.pauseBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            State.isPaused = !State.isPaused;
            Store.setPaused(State.isPaused);
            if (State.isPaused) {
                if (State.taskRefreshTimer) {
                    clearInterval(State.taskRefreshTimer);
                    State.taskRefreshTimer = null;
                }
            } else {
                if (State.refreshInterval > 0) {
                    restartRefreshTimer();
                }
            }
            updatePauseUI();
            Log.add(State.isPaused ? '已暂停' : '已恢复', State.isPaused ? 'pause' : 'success');
        });

        $.autoOpenBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            State.autoOpen = !State.autoOpen;
            Store.setAutoOpen(State.autoOpen);
            $.autoOpenBtn.classList.toggle('active', State.autoOpen);
            $.autoOpenBtn.textContent = State.autoOpen ? '自动开:开' : '自动开:关';
            Log.add(State.autoOpen ? '自动打开已启用（仅普通新EP）' : '自动打开已关闭', State.autoOpen ? 'auto' : 'info');
        });

        $.resetBtn.addEventListener('click', function(e) { e.stopPropagation(); Stats.reset(); });
        $.clearLogBtn.addEventListener('click', function(e) { e.stopPropagation(); Log.clear(); });

        if ($.getFailEpBtn) {
            $.getFailEpBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                if (State.failedEpsLoading) return;
                State.failedEpsLoaded = false;
                State.failedEps = [];
                $.getFailEpBtn.classList.add('loading');
                $.getFailEpBtn.textContent = '扫描中...';
                API.fetchFailedEpsFromAllTasks();
            });
        }
    }

    function restartRefreshTimer() {
        if (State.taskRefreshTimer) {
            clearInterval(State.taskRefreshTimer);
            State.taskRefreshTimer = null;
        }
        var interval = State.refreshInterval;
        if (interval <= 0) return;
        State.taskRefreshTimer = setInterval(function() {
            if (INSTANCE.phase !== 'running') {
                clearInterval(State.taskRefreshTimer);
                State.taskRefreshTimer = null;
                return;
            }
            if (!State.isPaused) {
                API.fetchTasks();
                // 自动刷新验收失败EP（仅在已加载过的情况下，静默更新）
                if (State.failedEpsLoaded) {
                    API.fetchFailedEpsFromAllTasks(true);
                }
            }
        }, interval);
    }

    function bindConfigEvents() {
        var pauseSwitch = document.getElementById('pauseSwitch');
        var autoOpenSwitch = document.getElementById('autoOpenSwitch');
        var showAllJobsSwitch = document.getElementById('showAllJobsSwitch');
        var saveConfigBtn = document.getElementById('saveConfigBtn');
        var resetStatsBtn = document.getElementById('resetStatsBtn');
        var clearLogsBtn = document.getElementById('clearLogsBtn');
        var refetchFailEpBtn = document.getElementById('refetchFailEpBtn');

        if (pauseSwitch) {
            pauseSwitch.addEventListener('click', function() {
                State.isPaused = !State.isPaused;
                Store.setPaused(State.isPaused);
                if (State.isPaused) {
                    if (State.taskRefreshTimer) {
                        clearInterval(State.taskRefreshTimer);
                        State.taskRefreshTimer = null;
                    }
                } else {
                    if (State.refreshInterval > 0) {
                        restartRefreshTimer();
                    }
                }
                updatePauseUI();
                Log.add(State.isPaused ? '已暂停刷新' : '已恢复刷新', State.isPaused ? 'pause' : 'success');
            });
        }

        if (autoOpenSwitch) {
            autoOpenSwitch.addEventListener('click', function() {
                State.autoOpen = !State.autoOpen;
                Store.setAutoOpen(State.autoOpen);
                autoOpenSwitch.classList.toggle('active', State.autoOpen);
                autoOpenSwitch.nextElementSibling.textContent = State.autoOpen ? '已开启(仅普通EP)' : '已关闭';
                Log.add(State.autoOpen ? '自动开:开' : '自动开:关');
            });
        }

        if (showAllJobsSwitch) {
            showAllJobsSwitch.addEventListener('click', function() {
                State.showAllJobs = !State.showAllJobs;
                Store.setShowAllJobs(State.showAllJobs);
                showAllJobsSwitch.classList.toggle('active', State.showAllJobs);
                showAllJobsSwitch.nextElementSibling.textContent = State.showAllJobs ? '已开启' : '已关闭';
                Log.add(State.showAllJobs ? '显示所有Job' : '仅显示待审Job');
                // 刷新任务列表以应用新设置
                if (INSTANCE.phase === 'running') {
                    API.fetchTasks();
                }
            });
        }

        if (saveConfigBtn) {
            saveConfigBtn.addEventListener('click', function() {
                var input = document.getElementById('refreshIntervalInput');
                if (!input) return;
                var seconds = Number(input.value);
                if (!Number.isFinite(seconds) || seconds < 0) seconds = 0;
                if (seconds > 600) seconds = 600;
                var newInterval = seconds * 1000;
                State.refreshInterval = newInterval;
                Store.setRefreshInterval(newInterval);

                var screenerInput = document.getElementById('screenerInput');
                if (screenerInput) {
                    State.screener = screenerInput.value.trim();
                    Store.setScreener(State.screener);
                }

                if (seconds === 0) {
                    State.isPaused = true;
                    Store.setPaused(true);
                    if (State.taskRefreshTimer) {
                        clearInterval(State.taskRefreshTimer);
                        State.taskRefreshTimer = null;
                    }
                    updatePauseUI();
                    Log.add('刷新已暂停（频率设为0）', 'info');
                } else {
                    restartRefreshTimer();
                    Log.add('刷新频率已设为：' + seconds + '秒', 'success');
                }
                if (State.screener) {
                    Log.add('初筛人已设置：' + State.screener, 'success');
                }
                renderConfig();
            });
        }

        if (resetStatsBtn) {
            resetStatsBtn.addEventListener('click', function() { Stats.reset(); });
        }

        if (clearLogsBtn) {
            clearLogsBtn.addEventListener('click', function() { Log.clear(); });
        }

        if (refetchFailEpBtn) {
            refetchFailEpBtn.addEventListener('click', function() {
                if (State.failedEpsLoading) return;
                State.failedEpsLoaded = false;
                State.failedEps = [];
                State.failedEpsLoading = false;
                Log.add('已重置验收失败EP缓存，开始重新扫描...', 'info');
                API.fetchFailedEpsFromAllTasks();
            });
        }
    }

    // 清理所有注入到页面的内容
    function cleanInjectedContent() {
        // 停止Observer并清理统计
        removeHeaderStats();

        // 清理资源面板
        document.querySelectorAll('#' + RESOURCE_PANEL_ID).forEach(function(el) { el.remove(); });

        // 清理侧边栏注入的菜单项
        document.querySelectorAll('.agibot-menu-divider').forEach(function(el) { el.remove(); });
        document.querySelectorAll('.agibot-menu-item').forEach(function(el) { el.remove(); });
        
        // 清理预览页EP链接按钮
        document.querySelectorAll('.ep-link-btn').forEach(function(el) { el.remove(); });
        
        // 清理列表加载指示器
        document.querySelectorAll('.list-loading').forEach(function(el) { el.remove(); });
    }

    function softCleanup() {
        INSTANCE.timerList.forEach(function(t) { try { clearTimeout(t); } catch (e) {} });
        INSTANCE.timerList.forEach(function(t) { try { clearInterval(t); } catch (e) {} });
        INSTANCE.timerList = [];

        INSTANCE.observers.slice().forEach(function(obs) {
            try { obs.disconnect(); } catch (e) {}
        });
        INSTANCE.observers = [];

        if (State.successObserver) { try { State.successObserver.disconnect(); } catch (e) {} State.successObserver = null; }
        if (State.taskRefreshTimer) { try { clearInterval(State.taskRefreshTimer); } catch (e) {} State.taskRefreshTimer = null; }
        if (INSTANCE.navigationTimer) { try { clearTimeout(INSTANCE.navigationTimer); } catch (e) {} INSTANCE.navigationTimer = null; }
        stopObservingStats();
        document.querySelectorAll('#' + RESOURCE_PANEL_ID).forEach(function(el) { el.remove(); });

        // 清理全局拖拽状态
        _dragging = false;
        _moved = false;
        _panelRef = null;
        _offsetX = 0;
        _offsetY = 0;

        // 清理注入的DOM元素
        cleanInjectedContent();

        State.checkMonitorActive = false;
        State.isRefreshing = false;
        console.log('[Agibot Monitor] 软清理完成（保留面板）');
    }

    function fullCleanup() {
        softCleanup();
        safeRemovePanel();
        safeRemoveResourcePanel();
        State.panelCreated = false;
        State.resourcePanelCreated = false;
        for (var key in $) { if (Object.prototype.hasOwnProperty.call($, key)) delete $[key]; }
        $ = {};
        console.log('[Agibot Monitor] 资源已完全清理');
    }

    async function startCheckMonitor() {
        if (State.successObserver) { try { State.successObserver.disconnect(); } catch (e) {} }
        State.successObserver = new MutationObserver(function(mutations) {
            for (var mi = 0; mi < mutations.length; mi++) {
                var mutation = mutations[mi];
                for (var ni = 0; ni < mutation.addedNodes.length; ni++) {
                    var node = mutation.addedNodes[ni];
                    if (node.nodeType !== 1) continue;
                    var msgEl = node.matches('.el-message,.el-message-box') ? node : node.querySelector('.el-message,.el-message-box');
                    if (!msgEl || msgEl.dataset.marked) continue;
                    if (msgEl.textContent.includes('标注成功')) {
                        msgEl.dataset.marked = '1';
                        Stats.add();
                    }
                }
            }
        });
        INSTANCE.observers.push(State.successObserver);
        State.successObserver.observe(document.body, { childList: true, subtree: true });
        State.checkMonitorActive = true;
        INSTANCE.phase = 'running';

        try { await waitForBody(); } catch (e) { console.error('[Agibot Monitor] 等待 Body 超时', e); return; }
        addStyles();
        
        // 注入页头统计信息
        startObservingStats();
        
        // 注入侧边栏资源列表
        var taskId = PAGE.getTaskId();
        if (taskId) {
            var resources = await API.fetchResources(taskId);
            State.resources = resources;
            injectResourcesToSidebar(resources);
            console.log('[Agibot Monitor] 资源列表已注入侧边栏，共 ' + resources.length + ' 个资源');
        }

        // 初始化统计数据
        var todayFrames = Store.getTodayFrames();
        State.totalFrames = todayFrames;
        Stats.render();
        
        console.log('[Agibot Monitor] 审核页面注入完成');
    }

    // ====== 统计注入 - Genie Studio 模式：精确选择器 + Observer，成功即断开 ======
    var _statsObserver = null;
    var _statsInjecting = false;

    function injectStatsToHeader() {
        if (_statsInjecting) return true;
        if (document.getElementById('agibot-header-stats')) return true;

        var controlsBar = document.querySelector('.header-tool-controls');
        if (!controlsBar) return false;

        _statsInjecting = true;
        try {
            var statsEl = document.createElement('div');
            statsEl.id = 'agibot-header-stats';
            statsEl.className = 'agibot-header-stats';

            var todayFrames = Store.getTodayFrames();
            statsEl.innerHTML = '<span class="agibot-stat-label">今日</span>' +
                '<span class="agibot-stat-value agibot-stat-count">' + Stats.today() + '</span>' +
                '<span class="agibot-stat-sep">·</span>' +
                '<span class="agibot-stat-value agibot-stat-time">' + formatTimeShort(todayFrames) + '</span>';

            // 插入到工具栏最前面，跟其余元素一样从左到右显示
            controlsBar.insertBefore(statsEl, controlsBar.firstChild);
            return true;
        } finally { _statsInjecting = false; }
    }

    // Observer 模式：工具栏未就绪时监听 body 变化，出现即注入，成功即断开
    function startObservingStats() {
        if (_statsObserver) return;
        if (document.getElementById('agibot-header-stats')) return;

        _statsObserver = new MutationObserver(function() {
            if (injectStatsToHeader()) {
                stopObservingStats();
            }
        });
        _statsObserver.observe(document.body, { childList: true, subtree: true });
        // 立即尝试一次
        if (injectStatsToHeader()) {
            stopObservingStats();
        }
    }

    function stopObservingStats() {
        if (_statsObserver) {
            try { _statsObserver.disconnect(); } catch (e) {}
            _statsObserver = null;
        }
    }

    function removeHeaderStats() {
        stopObservingStats();
        _statsInjecting = false;
        document.querySelectorAll('#agibot-header-stats').forEach(function(el) { el.remove(); });
    }

    // 注入资源列表到侧边栏 - 模仿导航栏样式
    function injectResourcesToSidebar(resources) {
        // 移除旧的资源注入
        var old = document.getElementById('agibot-sidebar-resources');
        if (old) old.remove();

        // 查找侧边栏导航容器
        var sidebar = document.querySelector('.el-menu, [class*="sidebar"] ul, [class*="Sidebar"] ul, nav ul');
        if (!sidebar) {
            var navItems = document.querySelectorAll('.el-menu-item, [class*="menu-item"], [class*="NavItem"]');
            if (navItems.length > 0) {
                sidebar = navItems[0].parentElement;
            }
        }

        if (!sidebar) {
            console.warn('[Agibot Monitor] 未找到侧边栏容器');
            return;
        }

        // 创建容器（带ID，用于重复检查）
        var container = document.createElement('div');
        container.id = 'agibot-sidebar-resources';

        // 创建分隔线
        var divider = document.createElement('li');
        divider.className = 'agibot-menu-divider';
        container.appendChild(divider);

        // 创建"资源列表"菜单项（模仿导航项样式）
        var sectionItem = document.createElement('li');
        sectionItem.className = 'agibot-menu-item agibot-menu-section';
        sectionItem.innerHTML = '<span class="agibot-menu-icon">📦</span><span class="agibot-menu-text">资源列表</span>' +
            '<span class="agibot-menu-arrow">›</span>';
        container.appendChild(sectionItem);

        // 创建资源子列表
        if (resources && resources.length > 0) {
            resources.forEach(function(name) {
                var li = document.createElement('li');
                li.className = 'agibot-menu-item agibot-menu-sub';
                li.innerHTML = '<span class="agibot-menu-icon">·</span><span class="agibot-menu-text">' + safeEncode(name) + '</span>';
                container.appendChild(li);
            });
        } else {
            var empty = document.createElement('li');
            empty.className = 'agibot-menu-item agibot-menu-sub agibot-menu-empty';
            empty.innerHTML = '<span class="agibot-menu-text">暂无资源</span>';
            container.appendChild(empty);
        }

        sidebar.appendChild(container);
        console.log('[Agibot Monitor] 资源列表已注入侧边栏（导航样式）');
    }

    async function initResourcePanel() {
        if (!PAGE.isCheck()) return;
        var taskId = PAGE.getTaskId();
        if (!taskId) {
            console.warn('[Agibot Monitor] 无法提取 task_id');
            return;
        }
        try { await waitForBody(); } catch (e) { console.error('[Agibot Monitor] 等待 Body 超时', e); return; }
        addStyles();
        var resources = await API.fetchResources(taskId);
        if (resources.length > 0) {
            State.resources = resources;
            buildResourcePanel(resources);
            console.log('[Agibot Monitor] 资源面板已加载，共 ' + resources.length + ' 个资源');
        } else {
            safeRemoveResourcePanel();
        }
    }

    async function initTaskListPage(startToken) {
        try { await waitForBody(); } catch (e) { console.error('[Agibot Monitor] 等待 Body 超时', e); return; }

        if (startToken !== undefined && startToken !== INSTANCE.startToken) {
            return;
        }

        addStyles();
        INSTANCE.phase = 'running';
        console.log('[Agibot Monitor] 任务列表页面已加载（无面板模式）');
        
        var todayFrames = Store.getTodayFrames();
        if (todayFrames > 0) {
            console.log('[Agibot Monitor] 今日累计审核视频时长：' + formatTime(todayFrames));
        }
    }

    function patchHistory() {
        var originalPushState = history.pushState;
        var originalReplaceState = history.replaceState;
        history.pushState = function() {
            originalPushState.apply(this, arguments);
            onRouteChange();
        };
        history.replaceState = function() {
            originalReplaceState.apply(this, arguments);
            onRouteChange();
        };
        window.addEventListener('popstate', onRouteChange);
    }

    function onRouteChange() {
        if (!window[SCRIPT_KEY]) return;

        INSTANCE.routeToken++;
        var myToken = INSTANCE.routeToken;

        if (INSTANCE.navigationTimer) {
            clearTimeout(INSTANCE.navigationTimer);
            INSTANCE.navigationTimer = null;
        }

        INSTANCE.navigationTimer = setTimeout(function() {
            if (myToken !== INSTANCE.routeToken) return;
            softCleanup();
            start(myToken);
        }, CONFIG.DEBOUNCE_MS);
    }

    async function start(token) {
        if (token !== undefined && token !== INSTANCE.routeToken) {
            return;
        }

        var isNavigationRestart = (token !== undefined);

        if (INSTANCE.phase === 'starting' || INSTANCE.phase === 'running') {
            if (isNavigationRestart) {
                // 路由变化触发：软清理（保留面板）
                softCleanup();
            } else {
                return;
            }
        }

        if (!INSTANCE.historyPatched) {
            patchHistory();
            INSTANCE.historyPatched = true;
        }

        INSTANCE.startToken = (INSTANCE.startToken || 0) + 1;
        var myStartToken = INSTANCE.startToken;

        INSTANCE.phase = 'starting';

        if (window[SCRIPT_KEY]) {
            if (isNavigationRestart) {
                // 导航重启：软清理以保留面板
                softCleanup();
            } else {
                // 首次启动：完全清理
                fullCleanup();
            }
        }
        window[SCRIPT_KEY] = INSTANCE;

        Store.cleanOldEps();
        State.autoOpen = Store.getAutoOpen();
        State.isPaused = Store.getPaused();
        State.refreshInterval = Store.getRefreshInterval();
        State.screener = Store.getScreener();
        State.showAllJobs = Store.getShowAllJobs();
        State.totalFrames = Store.getTodayFrames();
        State.initialized = false;
        INSTANCE.initialized = false;
        State.failedEps = [];
        State.failedEpsLoading = false;
        State.failedEpsLoaded = false;
        State.currentTaskEps = {};

        if (PAGE.isCheck()) {
            // 审核页面：先清理旧注入，再创建新注入
            cleanInjectedContent();
            safeRemovePanel();
            safeRemoveResourcePanel();
            try { await waitForBody(); if (myStartToken !== INSTANCE.startToken) { INSTANCE.phase = 'idle'; return; } startCheckMonitor(); } catch (e) { console.error('[Agibot Monitor] Check 页面启动异常', e); INSTANCE.phase = 'idle'; }
            return;
        }

        if (PAGE.isPreview()) {
            // 预览页面：先清理旧注入
            cleanInjectedContent();
            safeRemovePanel();
            safeRemoveResourcePanel();
            try { await waitForBody(); if (myStartToken !== INSTANCE.startToken) { INSTANCE.phase = 'idle'; return; } addStyles(); initPreviewPage(); } catch (e) { console.error('[Agibot Monitor] Preview 页面启动异常', e); INSTANCE.phase = 'idle'; }
            return;
        }

        if (myStartToken !== INSTANCE.startToken) {
            INSTANCE.phase = 'idle';
            return;
        }

        // 非审核/预览页面：清理所有注入
        cleanInjectedContent();
        safeRemoveResourcePanel();
        initTaskListPage(myStartToken);
    }

    var _previewObserver = null;

    function initPreviewPage() {
        if (_previewObserver) { try { _previewObserver.disconnect(); } catch (e) {} }
        
        injectEpLinkButtons();
        
        _previewObserver = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                if (mutations[i].addedNodes.length > 0) {
                    injectEpLinkButtons();
                    break;
                }
            }
        });
        
        _previewObserver.observe(document.body, { childList: true, subtree: true });
        INSTANCE.observers.push(_previewObserver);
        INSTANCE.phase = 'running';
        console.log('[Agibot Monitor] 预览页EP链接注入已启动');
    }

    function injectEpLinkButtons() {
        // 从当前URL解析taskId和jobId
        var urlParams = new URLSearchParams(window.location.search);
        var taskId = urlParams.get('taskId') || '';
        var jobId = urlParams.get('jobId') || '';

        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
            acceptNode: function(node) {
                if (/^id:\s*\d+/.test(node.textContent.trim())) {
                    var parent = node.parentNode;
                    if (parent && parent.classList && parent.classList.contains('ep-link-btn')) {
                        return NodeFilter.FILTER_REJECT;
                    }
                    return NodeFilter.FILTER_ACCEPT;
                }
                return NodeFilter.FILTER_REJECT;
            }
        });

        var nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);

        nodes.forEach(function(textNode) {
            var text = textNode.textContent.trim();
            var match = text.match(/id:\s*(\d+)/);
            if (!match) return;

            var epId = match[1];
            var parent = textNode.parentNode;
            
            if (parent.querySelector('.ep-link-btn[data-ep-id="' + epId + '"]')) return;

            // 构造完整URL：/data/collection/tasks/{taskId}/jobs/{jobId}/episodes/{epId}/check
            var url = API_BASE + '/data/collection';
            if (taskId && jobId) {
                url += '/tasks/' + taskId + '/jobs/' + jobId;
            }
            url += '/episodes/' + epId + '/check';

            var btn = document.createElement('a');
            btn.className = 'ep-link-btn';
            btn.dataset.epId = epId;
            btn.href = url;
            btn.target = '_blank';
            btn.textContent = '→审核';
            btn.title = '跳转到EP #' + epId + ' 的审核页面';
            
            parent.appendChild(btn);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            var launchTimer = setTimeout(start, 100);
            INSTANCE.timerList.push(launchTimer);
        }, { once: true });
    } else {
        var launchTimer = setTimeout(start, 100);
        INSTANCE.timerList.push(launchTimer);
    }

    window.addEventListener('beforeunload', fullCleanup);

    // 持续监控面板重复创建
    var panelObserver = new MutationObserver(function() {
        if (document.querySelectorAll('#' + PANEL_ID).length > 1 ||
            document.querySelectorAll('#' + RESOURCE_PANEL_ID).length > 1) {
            killDuplicatePanels();
        }
    });
    var startObserver = function() {
        if (document.body) {
            panelObserver.observe(document.body, { childList: true, subtree: true });
            killDuplicatePanels();
        } else {
            setTimeout(startObserver, 100);
        }
    };
    startObserver();
    window.addEventListener('load', killDuplicatePanels);
})();

