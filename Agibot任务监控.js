// ==UserScript==
// @name         Agibot任务监控
// @namespace    http://tampermonkey.net/
// @version      8.0.0
// @description  删除悬浮面板，标注成功通知本地应用 + 预览页EP链接注入
// @author       zero_K
// @match        https://tgs-geniestudio.agibot.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_addStyle
// @connect      localhost
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // ====================== 配置 ======================
    const CONFIG = {
        APP_NOTIFY_URL: 'http://localhost:18080',
        SUCCESS_DEBOUNCE: 3000,
        API_BASE: 'https://tgs-geniestudio.agibot.com',
    };

    const SCRIPT_KEY = '__AGIBOT_MONITOR_V8__';

    // 防止重复运行
    if (window[SCRIPT_KEY]) {
        console.log('[Agibot监控] 脚本实例已存在，终止重复运行');
        return;
    }
    window[SCRIPT_KEY] = true;

    // ====================== 状态 ======================
    let lastSuccessTime = 0;
    let checkMonitorActive = false;
    let successObserver = null;

    // ====================== 页面判断 ======================
    const PAGE = {
        isCheck: () => /\/episodes\/\d+\/check/.test(location.href),
        isPreview: () => /\/collection\/episode\/preview/.test(location.href),
        getEpisodeId: () => {
            const match = location.pathname.match(/\/episodes\/(\d+)/);
            return match ? parseInt(match[1]) : null;
        },
        getTaskId: () => {
            const match = location.pathname.match(/\/tasks\/(\d+)/);
            return match ? parseInt(match[1]) : null;
        },
    };

    // ====================== 日志 ======================
    const Log = {
        info: (msg) => console.log('[Agibot监控]', msg),
        success: (msg) => console.log('[Agibot监控] ✅', msg),
        error: (msg) => console.error('[Agibot监控] ❌', msg),
    };

    // ====================== 通知本地应用 ======================
    function notifyApp(episodeId, taskId) {
        const data = {
            type: 'review_success',
            episodeId: episodeId || 0,
            taskId: taskId || 0,
            message: '标注成功',
        };

        GM_xmlhttpRequest({
            method: 'POST',
            url: CONFIG.APP_NOTIFY_URL,
            headers: { 'Content-Type': 'application/json' },
            data: JSON.stringify(data),
            onload(res) {
                if (res.status === 200) {
                    Log.success(`已通知本地应用: EP ${episodeId}`);
                } else {
                    Log.error(`通知失败: HTTP ${res.status}`);
                }
            },
            onerror() {
                // 通知失败不影响正常使用
                Log.error('无法连接本地应用（是否未启动？）');
            },
        });
    }

    // ====================== Check 页面监控（检测标注成功）======================
    const CheckMonitor = {
        init() {
            if (checkMonitorActive) return;
            checkMonitorActive = true;

            if (successObserver) successObserver.disconnect();
            successObserver = new MutationObserver((muts) => {
                for (const m of muts) {
                    for (const n of m.addedNodes) {
                        if (n.nodeType !== 1) continue;
                        const t = n.matches('.el-message, .el-message-box')
                            ? n
                            : n.querySelector('.el-message, .el-message-box');
                        if (!t || t.dataset.marked) continue;
                        if (t.textContent.includes('标注成功')) {
                            t.dataset.marked = '1';
                            handleReviewSuccess();
                        }
                    }
                }
            });

            successObserver.observe(document.body, {
                childList: true,
                subtree: true,
            });

            Log.info('Check 页面监控已启动');
        },

        destroy() {
            if (successObserver) {
                successObserver.disconnect();
                successObserver = null;
            }
            checkMonitorActive = false;
        },

        checkAndInit() {
            if (PAGE.isCheck()) {
                if (!checkMonitorActive) CheckMonitor.init();
            } else {
                if (checkMonitorActive) CheckMonitor.destroy();
            }
        },
    };

    // ====================== 标注成功处理 ======================
    function handleReviewSuccess() {
        const now = Date.now();
        if (now - lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;
        lastSuccessTime = now;

        const episodeId = PAGE.getEpisodeId();
        const taskId = PAGE.getTaskId();

        Log.success(`标注成功: EP ${episodeId}, 任务 ${taskId}`);
        notifyApp(episodeId, taskId);
    }

    // ====================== 预览页 EP 链接注入 ======================
    function injectEpLinkButtons() {
        const urlParams = new URLSearchParams(window.location.search);
        const taskId = urlParams.get('taskId') || '';
        const jobId = urlParams.get('jobId') || '';

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
            acceptNode(node) {
                if (/^id:\s*\d+/.test(node.textContent.trim())) {
                    const parent = node.parentNode;
                    if (parent && parent.classList && parent.classList.contains('ep-link-btn')) {
                        return NodeFilter.FILTER_REJECT;
                    }
                    return NodeFilter.FILTER_ACCEPT;
                }
                return NodeFilter.FILTER_REJECT;
            },
        });

        const nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);

        nodes.forEach((textNode) => {
            const text = textNode.textContent.trim();
            const match = text.match(/id:\s*(\d+)/);
            if (!match) return;

            const epId = match[1];
            const parent = textNode.parentNode;

            if (parent.querySelector(`.ep-link-btn[data-ep-id="${epId}"]`)) return;

            let url = CONFIG.API_BASE + '/data/collection';
            if (taskId && jobId) {
                url += `/tasks/${taskId}/jobs/${jobId}`;
            }
            url += `/episodes/${epId}/check`;

            const btn = document.createElement('a');
            btn.className = 'ep-link-btn';
            btn.dataset.epId = epId;
            btn.href = url;
            btn.target = '_blank';
            btn.textContent = '→审核';
            btn.title = `跳转到 EP #${epId} 的审核页面`;

            parent.appendChild(btn);
        });
    }

    // ====================== 注入样式 ======================
    function addStyles() {
        GM_addStyle(`
            .ep-link-btn {
                display: inline-block;
                margin-left: 8px;
                padding: 2px 8px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: #fff;
                border-radius: 4px;
                text-decoration: none;
                font-size: 12px;
                cursor: pointer;
                transition: all 0.2s;
            }
            .ep-link-btn:hover {
                opacity: 0.8;
                transform: translateY(-1px);
            }
        `);
    }

    // ====================== 初始化预览页面 ======================
    function initPreviewPage() {
        addStyles();
        injectEpLinkButtons();

        const observer = new MutationObserver((muts) => {
            for (let i = 0; i < muts.length; i++) {
                if (muts[i].addedNodes.length > 0) {
                    injectEpLinkButtons();
                    break;
                }
            }
        });

        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        }

        Log.info('预览页 EP 链接注入已启动');
    }

    // ====================== 主启动 ======================
    function start() {
        Log.info('脚本初始化...');

        // 根据页面类型初始化
        if (PAGE.isCheck()) {
            CheckMonitor.init();
        } else if (PAGE.isPreview()) {
            initPreviewPage();
        } else {
            Log.info('其他页面，等待跳转...');
        }

        // 监听 URL 变化（SPA 应用）
        let lastUrl = location.href;
        setInterval(() => {
            if (location.href !== lastUrl) {
                lastUrl = location.href;
                Log.info('页面切换: ' + location.href);

                if (PAGE.isCheck()) {
                    CheckMonitor.init();
                } else if (PAGE.isPreview()) {
                    initPreviewPage();
                } else {
                    CheckMonitor.destroy();
                }
            }
        }, 1000);

        Log.info('脚本初始化完成');
    }

    // ====================== 启动 ======================
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        setTimeout(start, 500);
    } else {
        window.addEventListener('load', () => setTimeout(start, 500));
    }
})();
