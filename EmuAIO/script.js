async function fetchVersionInfo() {
    try {
        const response = await fetch('/version.json');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const versionData = await response.json();
        updateVersionDisplay(versionData);
        updateDownloadButtons(versionData);
    } catch (error) {
        console.error('获取版本信息失败:', error);
        // 使用默认版本信息作为后备
        const fallbackData = {
            Version: "2.1.1.3",
            LastUpdate: "26-01-25-15-00",
            download: "#"
        };
        updateVersionDisplay(fallbackData);
    }
}

// 更新页面显示的版本信息
function updateVersionDisplay(versionData) {
    // 更新版本号
    const versionElements = document.querySelectorAll('.version-value');
    versionElements.forEach(element => {
        if (element.textContent.includes('v')) {
            element.textContent = `v${versionData.Version}`;
        } else if (element.textContent.includes('26-01-25')) {
            element.textContent = versionData.LastUpdate;
        }
    });
    
    // 更新下载按钮的版本信息
    const downloadButtons = document.querySelectorAll('[href*="download"]');
    downloadButtons.forEach(button => {
        if (button.textContent.includes('v')) {
            button.innerHTML = button.innerHTML.replace(/v[\d.]+/, `v${versionData.Version}`);
        }
    });
    
    // 更新页面标题（可选）
    document.title = `EmuAIO v${versionData.Version} - 动车组全信息查询系统`;
    
    console.log(`版本信息已更新: v${versionData.Version} (${versionData.LastUpdate})`);
}

// 更新下载按钮的链接
function updateDownloadButtons(versionData) {
    // 更新QQ群下载链接
    const qqGroupLink = document.querySelector('a[href*="qm.qq.com"]');
    if (qqGroupLink && versionData.download1) {
        qqGroupLink.href = versionData.download1;
    }
    
    // 更新直接下载链接（如果有）
    const directDownloadLinks = document.querySelectorAll('a[href*="download"]');
    directDownloadLinks.forEach(link => {
        if (link.href.includes('github.com') && versionData.download) {
            link.href = versionData.download;
        }
    });
}

// 导航栏功能

document.addEventListener('DOMContentLoaded', function() {
    // 移动端菜单切换
    const menuToggle = document.getElementById('menu-toggle');
    const navLinks = document.getElementById('nav-links');

    fetchVersionInfo();
    
    if (menuToggle && navLinks) {
        menuToggle.addEventListener('click', function() {
            navLinks.classList.toggle('active');
        });
        
        // 点击导航链接时关闭菜单
        const navItems = navLinks.querySelectorAll('.nav-link');
        navItems.forEach(item => {
            item.addEventListener('click', function() {
                navLinks.classList.remove('active');
            });
        });
    }
    
    // 导航链接激活状态
    const sections = document.querySelectorAll('section');
    const navItems = document.querySelectorAll('.nav-link');
    
    function setActiveNavItem() {
        let current = '';
        const scrollPos = window.scrollY + 100;
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            
            if (scrollPos >= sectionTop && scrollPos < sectionTop + sectionHeight) {
                current = section.getAttribute('id');
            }
        });
        
        navItems.forEach(item => {
            item.classList.remove('active');
            if (item.getAttribute('href').substring(1) === current) {
                item.classList.add('active');
            }
        });
    }
    
    window.addEventListener('scroll', setActiveNavItem);
    
    // 下载按钮功能
    const downloadButtons = {
        'android-download': {
            message: '您确定要下载 Android 版本 (v2.1.1.2) 吗？',
            confirmText: '立即下载',
            fileUrl: '#'
        }
    };
    
    Object.keys(downloadButtons).forEach(buttonId => {
        const button = document.getElementById(buttonId);
        if (button) {
            button.addEventListener('click', function(e) {
                e.preventDefault();
                const config = downloadButtons[buttonId];
                showDownloadModal(config);
            });
        }
    });
    
    // 页脚链接
    const footerLinks = ['faq-link', 'contact-link', 'report-link', 'privacy-link', 'terms-link', 'license-link'];
    
    footerLinks.forEach(linkId => {
        const link = document.getElementById(linkId);
        if (link) {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                showInfoModal(linkId);
            });
        }
    });
    
    // 弹窗功能
    const modal = document.getElementById('download-modal');
    const modalClose = document.getElementById('modal-close');
    const modalCancel = document.getElementById('modal-cancel');
    const modalConfirm = document.getElementById('modal-confirm');
    const modalMessage = document.getElementById('modal-message');
    
    let currentDownloadConfig = null;
    
    function showDownloadModal(config) {
        currentDownloadConfig = config;
        modalMessage.textContent = config.message;
        modalConfirm.textContent = config.confirmText;
        modal.classList.add('active');
    }
    
    function showInfoModal(type) {
        const messages = {
            'faq-link': {
                message: '常见问题页面正在开发中，敬请期待！',
                confirmText: '确定'
            },
            'contact-link': {
                message: '联系我们：iceiswpan@163.com',
                confirmText: '复制邮箱'
            },
            'report-link': {
                message: '问题反馈请发送邮件至：iceiswpan@163.com',
                confirmText: '确定'
            },
            'privacy-link': {
                message: '隐私政策：本应用尊重并保护所有用户的个人隐私权。',
                confirmText: '确定'
            },
            'terms-link': {
                message: '使用条款：本应用仅供学习和参考使用。',
                confirmText: '确定'
            },
            'license-link': {
                message: '开源许可：本项目采用 MIT 许可证。',
                confirmText: '确定'
            }
        };
        
        const config = messages[type] || { message: '页面正在开发中', confirmText: '确定' };
        currentDownloadConfig = null;
        modalMessage.textContent = config.message;
        modalConfirm.textContent = config.confirmText;
        modal.classList.add('active');
    }
    
    // 关闭弹窗
    function closeModal() {
        modal.classList.remove('active');
    }
    
    if (modalClose) {
        modalClose.addEventListener('click', closeModal);
    }
    
    if (modalCancel) {
        modalCancel.addEventListener('click', closeModal);
    }
    
    if (modalConfirm) {
        modalConfirm.addEventListener('click', function() {
            if (currentDownloadConfig) {
                if (currentDownloadConfig.isExternal) {
                    window.open(currentDownloadConfig.fileUrl, '_blank');
                } else {
                    // 模拟下载
                    const link = document.createElement('a');
                    link.href = currentDownloadConfig.fileUrl;
                    link.download = `EmuAIO-v2.1.1.2.apk`;
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                    
                    // 显示下载成功消息
                    setTimeout(() => {
                        modalMessage.textContent = '下载已开始，请稍候...';
                        modalConfirm.textContent = '确定';
                        currentDownloadConfig = null;
                    }, 1000);
                    
                    return;
                }
            } else if (modalConfirm.textContent === '复制邮箱') {
                // 复制邮箱到剪贴板
                navigator.clipboard.writeText('iceiswpan@163.com')
                    .then(() => {
                        modalMessage.textContent = '邮箱地址已复制到剪贴板！';
                    })
                    .catch(err => {
                        modalMessage.textContent = '复制失败，请手动复制：iceiswpan@163.com';
                    });
                return;
            }
            
            closeModal();
        });
    }
    
    // 点击弹窗外部关闭
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            closeModal();
        }
    });
    
    // 滚动动画
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
            }
        });
    }, observerOptions);
    
    // 观察需要动画的元素
    const animatedElements = document.querySelectorAll('.feature-card, .platform-card, .developer-card');
    animatedElements.forEach(el => {
        observer.observe(el);
    });
    
    // 添加CSS动画
    const style = document.createElement('style');
    style.textContent = `
        .animate-in {
            animation: fadeInUp 0.6s ease forwards;
        }
        
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .feature-card, .platform-card, .developer-card {
            opacity: 0;
        }
    `;
    document.head.appendChild(style);
    
    // 随机生成统计数据
    function updateStats() {
        const statNumbers = document.querySelectorAll('.stat-number');
        if (statNumbers.length === 4) {
            // 模拟动态增长
            const targetValues = [10000, 18, 3, 24];
            statNumbers.forEach((stat, index) => {
                let current = 0;
                const target = targetValues[index];
                const increment = target / 50;
                const timer = setInterval(() => {
                    current += increment;
                    if (current >= target) {
                        current = target;
                        clearInterval(timer);
                    }
                    stat.textContent = index === 0 ? 
                        Math.floor(current).toLocaleString() + '+' : 
                        index === 3 ? 
                        Math.floor(current) + '/7' : 
                        Math.floor(current);
                }, 20);
            });
        }
    }
    
    // 页面加载完成后更新统计
    setTimeout(updateStats, 1000);
    
    // 搜索框交互
    const searchInput = document.querySelector('.search-input input');
    const searchBtn = document.querySelector('.search-btn');
    
    if (searchInput && searchBtn) {
        searchInput.addEventListener('focus', function() {
            this.parentElement.style.boxShadow = '0 0 0 3px rgba(77, 182, 172, 0.2)';
            this.parentElement.style.borderColor = '#4DB6AC';
        });
        
        searchInput.addEventListener('blur', function() {
            this.parentElement.style.boxShadow = 'none';
            this.parentElement.style.borderColor = '#ddd';
        });
        
        searchBtn.addEventListener('click', function() {
            const query = searchInput.value.trim();
            if (query) {
                modalMessage.textContent = `正在搜索 "${query}"...\n\n搜索功能在演示中不可用，请在真实应用中体验完整功能。`;
                modalConfirm.textContent = '确定';
                currentDownloadConfig = null;
                modal.classList.add('active');
            } else {
                searchInput.parentElement.style.borderColor = '#e74c3c';
                setTimeout(() => {
                    searchInput.parentElement.style.borderColor = '#ddd';
                }, 1000);
            }
        });
        
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                searchBtn.click();
            }
        });
    }
    
    // 添加加载动画
    window.addEventListener('load', function() {
        document.body.style.opacity = 0;
        document.body.style.transition = 'opacity 0.5s ease';
        
        setTimeout(() => {
            document.body.style.opacity = 1;
        }, 100);
    });
    
    // 控制台欢迎信息
    console.log('%c🚄 EmuAIO - 动车组全信息查询系统', 'color: #4DB6AC; font-size: 18px; font-weight: bold;');
    console.log('%c欢迎开发者！这是一个Flutter应用官网演示。', 'color: #666; font-size: 14px;');
    console.log('%cGitHub: https://github.com/CrYinLang/EmuAIO', 'color: #666; font-size: 12px;');

});