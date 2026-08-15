// ==UserScript==
// @name         智元标注审核助手 (zero_K-Genie版)
// @namespace    http://tampermonkey.net/
// @version      9.0.0
// @description  保留页面注入 + 标注成功通知本地应用
// @author       zero_K
// @match        https://tgs-geniestudio.agibot.com/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_addStyle
// @grant        GM_xmlhttpRequest
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    // 配置
    const CONFIG = {
        APP_NOTIFY_URL: 'http://localhost:18080',
        SUCCESS_DEBOUNCE: 3000,
        API_BASE: "https://tgs-geniestudio.agibot.com",
    };

    const SCRIPT_KEY = "__AGIBOT_MONITOR_V3__";

    // 防止重复运行
    if (window[SCRIPT_KEY]) {
        console.log('[zero_K-Genie] 脚本实例已存在，终止重复运行');
        return;
    }
    window[SCRIPT_KEY] = true;

    // 状态
    let lastSuccessTime = 0;
    let checkMonitorActive = false;

    // 页面判断
    const PAGE = {
        isCheck: () => /\/episodes\/\d+\/check/.test(location.href),
        isPreview: () => /\/collection\/episode\/preview/.test(location.href),
        getTaskId: () => {
            const match = location.href.match(/\/tasks\/(\d+)\/jobs/);
            return match ? match[1] : null;
        }
    };

    // 日志
    const Log = {
        info: (msg) => console.log('[zero_K-Genie]', msg),
        success: (msg) => console.log('[zero_K-Genie] ✅', msg),
        error: (msg) => console.error('[zero_K-Genie] ❌', msg),
    };

    // ========== 通知本地应用 ==========
    function notifyApp(episodeId) {
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
                    Log.success('已通知本地应用');
                }
            },
            onerror() {
                // 通知失败不影响正常使用
            }
        });
    }

    // ========== Check页面监控（检测标注成功）==========
    function startCheckMonitor() {
        if (checkMonitorActive) return;
        checkMonitorActive = true;
        
        Log.info('Check页面监控已启动');

        // 监听页面变化，检测标注成功
        const observer = new MutationObserver((mutations) => {
            detectSuccess();
        });
        
        if (document.body) {
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true
            });
        }

        // 监听按钮点击
        document.addEventListener('click', (event) => {
            const target = event.target;
            
            // 检测提交/确认按钮
            if (target.matches('button[type="submit"], .submit-btn, [class*="submit"], [class*="confirm"], [class*="approve"]')) {
                Log.info('检测到按钮点击: ' + (target.textContent || '').trim());
                
                // 等待一段时间后检查状态
                setTimeout(detectSuccess, 2000);
            }
        });
    }

    // 检测标注成功
    function detectSuccess() {
        const now = Date.now();
        if (now - lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;

        // 检测成功提示
        const successElements = document.querySelectorAll(
            '.success-message, .toast-success, [class*="success"], .el-message--success, .el-notification__content'
        );
        
        for (const el of successElements) {
            const text = el.textContent || '';
            if (text.includes('成功') || text.includes('完成') || text.includes('success')) {
                lastSuccessTime = now;
                
                // 从URL提取EP ID
                const match = location.pathname.match(/\/episodes\/(\d+)/);
                const episodeId = match ? parseInt(match[1]) : 0;
                
                Log.success(`标注成功: EP ${episodeId}`);
                notifyApp(episodeId);
                break;
            }
        }
    }

    // ========== 预览页面注入EP链接按钮 ==========
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

            // 构造完整URL
            var url = CONFIG.API_BASE + '/data/collection';
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

    // ========== 注入样式 ==========
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

    // ========== 初始化预览页面 ==========
    function initPreviewPage() {
        addStyles();
        injectEpLinkButtons();
        
        // 监听DOM变化，动态注入按钮
        const observer = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                if (mutations[i].addedNodes.length > 0) {
                    injectEpLinkButtons();
                    break;
                }
            }
        });
        
        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        }
        
        Log.info('预览页EP链接注入已启动');
    }

    // ========== 主启动函数 ==========
    function start() {
        Log.info('脚本初始化...');

        // 根据页面类型初始化
        if (PAGE.isCheck()) {
            // Check页面：启动监控
            startCheckMonitor();
        } else if (PAGE.isPreview()) {
            // 预览页面：注入EP链接按钮
            initPreviewPage();
        } else {
            // 其他页面：只监听URL变化
            Log.info('其他页面，等待跳转...');
        }

        // 监听URL变化
        let lastUrl = location.href;
        setInterval(() => {
            if (location.href !== lastUrl) {
                lastUrl = location.href;
                Log.info('页面切换: ' + location.href);
                
                // 根据新页面类型重新初始化
                if (PAGE.isCheck()) {
                    startCheckMonitor();
                } else if (PAGE.isPreview()) {
                    initPreviewPage();
                }
            }
        }, 1000);

        Log.info('脚本初始化完成');
    }

    // ========== 启动 ==========
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            setTimeout(start, 100);
        }, { once: true });
    } else {
        setTimeout(start, 100);
    }

})();
