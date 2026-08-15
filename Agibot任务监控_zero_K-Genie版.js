// ==UserScript==
// @name         Agibot 标注助手 (zero_K-Genie版)
// @namespace    http://tampermonkey.net/
// @version      1.0.0
// @description  页面注入 + 标注成功通知本地应用
// @author       zero_K
// @match        https://tgs-geniestudio.agibot.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_addStyle
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // 配置
    const CONFIG = {
        APP_NOTIFY_URL: 'http://localhost:18080',
        SUCCESS_DEBOUNCE: 3000,
    };

    // 状态
    let lastSuccessTime = 0;

    // 日志
    const Log = {
        info: (msg) => console.log('[zero_K-Genie]', msg),
        success: (msg) => console.log('[zero_K-Genie] ✅', msg),
        error: (msg) => console.error('[zero_K-Genie] ❌', msg),
    };

    // 通知本地应用
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

    // 从URL提取EP ID
    function getEpisodeId() {
        const match = location.pathname.match(/\/episodes\/(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }

    // 检测标注成功
    function detectSuccess() {
        // 检测成功提示
        const successElements = document.querySelectorAll(
            '.success-message, .toast-success, [class*="success"], .el-message--success, .el-notification__content'
        );
        
        for (const el of successElements) {
            const text = el.textContent || '';
            if (text.includes('成功') || text.includes('完成') || text.includes('success')) {
                const now = Date.now();
                if (now - lastSuccessTime < CONFIG.SUCCESS_DEBOUNCE) return;
                lastSuccessTime = now;
                
                const episodeId = getEpisodeId();
                Log.success(`标注成功: EP ${episodeId}`);
                notifyApp(episodeId);
                break;
            }
        }
    }

    // 监听页面变化
    function startObserver() {
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
        
        Log.info('页面监听已启动');
    }

    // 监听按钮点击
    function listenButtonClicks() {
        document.addEventListener('click', (event) => {
            const target = event.target;
            
            // 检测提交/确认按钮
            if (target.matches('button[type="submit"], .submit-btn, [class*="submit"], [class*="confirm"], [class*="approve"]')) {
                Log.info('检测到按钮点击: ' + (target.textContent || '').trim());
                
                // 等待一段时间后检查状态
                setTimeout(detectSuccess, 2000);
            }
        });
        
        Log.info('按钮监听已启动');
    }

    // 初始化
    function init() {
        Log.info('脚本初始化...');
        startObserver();
        listenButtonClicks();
        Log.info('脚本初始化完成');
    }

    // 启动
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
