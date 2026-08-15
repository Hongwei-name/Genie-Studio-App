// ==UserScript==
// @name         zero_K-Genie 标注助手
// @namespace    https://github.com/Hongwei-name/Genie-Studio-App
// @version      1.0.0
// @description  智元标注审核助手 - 浏览器端标注通知脚本
// @author       zero_K
// @match        *://tgs-geniestudio.agibot.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_notification
// @connect      localhost
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // 配置
    const CONFIG = {
        // 本地通知服务地址
        notificationUrl: 'http://localhost:18080',
        // 是否启用调试日志
        debug: true,
        // 监听的 DOM 变化类型
        observeOptions: {
            childList: true,
            subtree: true,
            attributes: true,
            characterData: true
        }
    };

    // 日志工具
    const Logger = {
        log: (...args) => {
            if (CONFIG.debug) {
                console.log('[zero_K-Genie]', ...args);
            }
        },
        success: (...args) => {
            if (CONFIG.debug) {
                console.log('[zero_K-Genie] ✅', ...args);
            }
        },
        error: (...args) => {
            console.error('[zero_K-Genie] ❌', ...args);
        }
    };

    // 通知服务
    const NotificationService = {
        /**
         * 发送通知到本地应用
         * @param {Object} data - 通知数据
         * @param {string} data.type - 通知类型 (review_success, review_failed, ping)
         * @param {number} [data.episodeId] - EP ID
         * @param {number} [data.taskId] - 任务 ID
         * @param {string} [data.message] - 消息内容
         */
        send(data) {
            Logger.log('发送通知:', data);

            GM_xmlhttpRequest({
                method: 'POST',
                url: CONFIG.notificationUrl,
                headers: {
                    'Content-Type': 'application/json'
                },
                data: JSON.stringify(data),
                onload(response) {
                    if (response.status === 200) {
                        const result = JSON.parse(response.responseText);
                        Logger.success('通知发送成功:', result);
                    } else {
                        Logger.error('通知发送失败:', response.status);
                    }
                },
                onerror(error) {
                    Logger.error('通知发送错误:', error);
                }
            });
        },

        /**
         * 发送标注成功通知
         * @param {number} episodeId - EP ID
         * @param {number} [taskId] - 任务 ID
         */
        sendReviewSuccess(episodeId, taskId) {
            this.send({
                type: 'review_success',
                episodeId: episodeId,
                taskId: taskId,
                message: '标注成功'
            });

            // 通知已发送到应用
        },

        /**
         * 发送标注失败通知
         * @param {number} episodeId - EP ID
         * @param {string} message - 失败原因
         */
        sendReviewFailed(episodeId, message) {
            this.send({
                type: 'review_failed',
                episodeId: episodeId,
                message: message
            });
        },

        /**
         * 发送心跳检测
         */
        sendPing() {
            this.send({
                type: 'ping',
                message: 'heartbeat'
            });
        }
    };

    // 标注状态检测器
    const ReviewDetector = {
        // 上一次检测到的状态
        lastState: null,

        // 已处理的 EP ID 集合
        processedEpIds: new Set(),

        /**
         * 从 URL 中提取 EP ID
         * @returns {number|null}
         */
        getEpisodeIdFromUrl() {
            const match = window.location.pathname.match(/\/episodes\/(\d+)/);
            return match ? parseInt(match[1]) : null;
        },

        /**
         * 从 URL 中提取任务 ID
         * @returns {number|null}
         */
        getTaskIdFromUrl() {
            const match = window.location.pathname.match(/\/tasks\/(\d+)/);
            return match ? parseInt(match[1]) : null;
        },

        /**
         * 检测标注成功状态
         * 根据页面内容判断是否标注成功
         */
        checkReviewSuccess() {
            // 方法1: 检测成功提示元素
            const successElements = document.querySelectorAll(
                '.success-message, .toast-success, [class*="success"], [class*="complete"]'
            );
            
            for (const el of successElements) {
                const text = el.textContent || '';
                if (text.includes('成功') || text.includes('完成') || text.includes('success')) {
                    return true;
                }
            }

            // 方法2: 检测按钮状态变化
            const submitButtons = document.querySelectorAll(
                'button[type="submit"], .submit-btn, [class*="submit"], [class*="confirm"]'
            );
            
            for (const btn of submitButtons) {
                if (btn.disabled && btn.textContent.includes('已提交')) {
                    return true;
                }
            }

            // 方法3: 检测页面跳转后的新状态
            const statusElements = document.querySelectorAll(
                '.status, [class*="status"], [class*="review-status"]'
            );
            
            for (const el of statusElements) {
                const text = el.textContent || '';
                if (text.includes('已审核') || text.includes('已标注')) {
                    return true;
                }
            }

            return false;
        },

        /**
         * 处理标注成功
         */
        handleReviewSuccess() {
            const episodeId = this.getEpisodeIdFromUrl();
            const taskId = this.getTaskIdFromUrl();

            if (episodeId && !this.processedEpIds.has(episodeId)) {
                this.processedEpIds.add(episodeId);
                Logger.success(`检测到标注成功: EP ${episodeId}`);
                NotificationService.sendReviewSuccess(episodeId, taskId);
            }
        },

        /**
         * 开始监听
         */
        start() {
            Logger.log('开始监听标注状态...');

            // 监听 DOM 变化
            const observer = new MutationObserver((mutations) => {
                if (this.checkReviewSuccess()) {
                    this.handleReviewSuccess();
                }
            });

            observer.observe(document.body, CONFIG.observeOptions);

            // 监听页面加载完成
            window.addEventListener('load', () => {
                Logger.log('页面加载完成');
                NotificationService.sendPing();
            });

            // 监听 URL 变化（SPA 应用）
            let lastUrl = window.location.href;
            const urlObserver = new MutationObserver(() => {
                if (window.location.href !== lastUrl) {
                    lastUrl = window.location.href;
                    Logger.log('URL 变化:', lastUrl);
                    
                    // 检查新页面是否标注成功
                    setTimeout(() => {
                        if (this.checkReviewSuccess()) {
                            this.handleReviewSuccess();
                        }
                    }, 1000);
                }
            });

            urlObserver.observe(document.body, {
                childList: true,
                subtree: true
            });

            // 定期发送心跳
            setInterval(() => {
                NotificationService.sendPing();
            }, 60000); // 每分钟一次

            Logger.log('监听已启动');
        }
    };

    // 按钮点击监听器
    const ButtonClickListener = {
        /**
         * 初始化按钮监听
         */
        init() {
            // 监听所有按钮点击
            document.addEventListener('click', (event) => {
                const target = event.target;
                
                // 检测提交/确认按钮
                if (target.matches('button[type="submit"], .submit-btn, [class*="submit"], [class*="confirm"], [class*="approve"]')) {
                    Logger.log('检测到按钮点击:', target.textContent);
                    
                    // 等待一段时间后检查状态
                    setTimeout(() => {
                        if (this.checkAfterClick()) {
                            ReviewDetector.handleReviewSuccess();
                        }
                    }, 2000);
                }
            });

            Logger.log('按钮监听已初始化');
        },

        /**
         * 点击后检查状态
         * @returns {boolean}
         */
        checkAfterClick() {
            // 检测成功提示
            const toasts = document.querySelectorAll('.toast, .notification, .alert, [class*="message"]');
            for (const toast of toasts) {
                const text = toast.textContent || '';
                if (text.includes('成功') || text.includes('完成')) {
                    return true;
                }
            }
            
            return false;
        }
    };

    // 初始化
    function init() {
        Logger.log('脚本初始化...');
        
        // 启动标注状态检测
        ReviewDetector.start();
        
        // 初始化按钮监听
        ButtonClickListener.init();
        
        Logger.log('脚本初始化完成');
    }

    // 等待页面加载完成后初始化
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();

