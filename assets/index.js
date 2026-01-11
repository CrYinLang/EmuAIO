// 主题管理功能
class ThemeManager {
    constructor() {
        this.currentTheme = this.getSavedTheme() || 'dark';
        this.init();
    }

    // 初始化主题
    init() {
        this.applyTheme(this.currentTheme);
        this.setupThemeListeners();
    }

    // 获取保存的主题
    getSavedTheme() {
        const settings = JSON.parse(localStorage.getItem('emuAioSettings')) || {};
        return settings.theme || 'dark';
    }

    // 应用主题
    applyTheme(theme) {
        document.body.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        
        // 更新设置页面的主题选项
        this.updateThemeRadioButtons(theme);
        
        // 保存主题设置
        this.saveThemeToSettings(theme);
    }

    // 切换主题
    toggleTheme() {
        const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        this.applyTheme(newTheme);
    }

    // 设置主题监听器
    setupThemeListeners() {
        // 监听设置页面的主题单选按钮
        document.addEventListener('change', (e) => {
            if (e.target.name === 'theme') {
                this.applyTheme(e.target.value);
            }
        });
    }

    // 更新主题单选按钮状态
    updateThemeRadioButtons(theme) {
        const darkRadio = document.getElementById('themeDark');
        const lightRadio = document.getElementById('themeLight');
        
        if (darkRadio) darkRadio.checked = (theme === 'dark');
        if (lightRadio) lightRadio.checked = (theme === 'light');
    }

    // 保存主题到设置
    saveThemeToSettings(theme) {
        const settings = JSON.parse(localStorage.getItem('emuAioSettings')) || {};
        settings.theme = theme;
        localStorage.setItem('emuAioSettings', JSON.stringify(settings));
    }

    // 获取当前主题
    getCurrentTheme() {
        return this.currentTheme;
    }

    // 检查是否是深色主题
    isDarkTheme() {
        return this.currentTheme === 'dark';
    }
}

// 设置页面功能 - 增强版，支持图标显示控制
class SettingsManager {
    constructor() {
        this.settings = this.loadSettings();
        this.init();
    }

    init() {
        this.loadAndApplySavedTheme();
        this.loadIconDisplaySettings();
        this.setupThemeListeners();
        this.setupIconSwitchListeners();
    }

    loadSettings() {
        return JSON.parse(localStorage.getItem('emuAioSettings')) || {
            theme: 'dark',
            showTrainIcons: true,
            showBureauIcons: true
        };
    }

    saveSettings() {
        localStorage.setItem('emuAioSettings', JSON.stringify(this.settings));
    }

    loadAndApplySavedTheme() {
        const savedTheme = this.settings.theme;
        
        // 选中对应的 radio
        const radio = document.querySelector(`input[name="theme"][value="${savedTheme}"]`);
        if (radio) radio.checked = true;
        
        // 立即应用
        if (window.themeManager) {
            window.themeManager.applyTheme(savedTheme);
        }
    }

    // 新增：加载图标显示设置
    loadIconDisplaySettings() {
        const trainIconSwitch = document.getElementById('trainIconSwitch');
        const bureauIconSwitch = document.getElementById('bureauIconSwitch');
        
        if (trainIconSwitch) {
            trainIconSwitch.checked = this.settings.showTrainIcons !== false; // 默认true
        }
        
        if (bureauIconSwitch) {
            bureauIconSwitch.checked = this.settings.showBureauIcons !== false; // 默认true
        }
    }

    setupThemeListeners() {
        document.querySelectorAll('input[name="theme"]').forEach(radio => {
            radio.addEventListener('change', (e) => {
                const selectedTheme = e.target.value;
                this.settings.theme = selectedTheme;
                this.saveSettings();
                
                if (window.themeManager) {
                    window.themeManager.applyTheme(selectedTheme);
                }
            });
        });
    }

    // 新增：设置图标开关监听器
    setupIconSwitchListeners() {
        const trainIconSwitch = document.getElementById('trainIconSwitch');
        const bureauIconSwitch = document.getElementById('bureauIconSwitch');
        
        if (trainIconSwitch) {
            trainIconSwitch.addEventListener('change', (e) => {
                this.settings.showTrainIcons = e.target.checked;
                this.saveSettings();
                this.showSettingsMessage('列车图标设置已保存', 'success');
            });
        }
        
        if (bureauIconSwitch) {
            bureauIconSwitch.addEventListener('change', (e) => {
                this.settings.showBureauIcons = e.target.checked;
                this.saveSettings();
                this.showSettingsMessage('路局图标设置已保存', 'success');
            });
        }
    }

    // 新增：显示设置保存提示
    showSettingsMessage(message, type = 'success') {
        // 移除现有的消息
        const existingMessage = document.querySelector('.settings-message');
        if (existingMessage) {
            existingMessage.remove();
        }
        
        // 创建新消息
        const messageDiv = document.createElement('div');
        messageDiv.className = `settings-message settings-message-${type}`;
        messageDiv.textContent = message;
        
        document.body.appendChild(messageDiv);
        
        // 3秒后自动消失
        setTimeout(() => {
            if (messageDiv.parentNode) {
                messageDiv.style.animation = 'slideOut 0.3s ease';
                setTimeout(() => messageDiv.remove(), 300);
            }
        }, 3000);
    }

    // 新增：获取图标显示设置（供其他模块使用）
    getIconDisplaySettings() {
        return {
            showTrainIcons: this.settings.showTrainIcons !== false,
            showBureauIcons: this.settings.showBureauIcons !== false
        };
    }
}

class MainApp {
    constructor() {
        this.cooldownSeconds = 3;
        this.lastQueryTime = 0;
        this.cooldownInterval = null;
        this.init();
    }

    // 初始化应用
    init() {
        this.setupEventListeners();
        this.setupTabNavigation();
        this.applyMinimalSettings();
        this.setupInputValidation();
        this.setupTrainSelectListener();
    }

    // 设置事件监听器
    setupEventListeners() {
        const searchInput = document.getElementById('searchInput');
        const searchBtn = document.getElementById('searchBtn');
        const searchTypeRadios = document.querySelectorAll('input[name="searchType"]');
        const showRoutesCheckbox = document.getElementById('showRoutes');
        const showRoutesLabel = document.querySelector('label[for="showRoutes"]');

        if (searchInput && searchBtn) {
            // 输入变化 → 更新按钮可用状态
            searchInput.addEventListener('input', () => {
                this.updateSearchBtnState(searchInput, searchBtn);
            });

            // 点击查询
            searchBtn.addEventListener('click', () => {
                this.handleSearch();
            });

            // 回车查询
            searchInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter' && !searchBtn.disabled) {
                    this.handleSearch();
                }
            });
        }

        // 监听查询类型切换，动态控制交路选项和TrainSelect
        if (searchTypeRadios.length > 0 && showRoutesCheckbox && showRoutesLabel) {
            searchTypeRadios.forEach(radio => {
                radio.addEventListener('change', (e) => {
                    this.toggleRoutesOptionVisibility(e.target.value);
                });
            });
            
            // 初始化状态
            const currentType = document.querySelector('input[name="searchType"]:checked')?.value || 'trainCode';
            this.toggleRoutesOptionVisibility(currentType);
        }
    }

    // 设置TrainSelect监听器
    setupTrainSelectListener() {
        const trainSelect = document.getElementById('TrainSelect');
        if (trainSelect) {
            trainSelect.addEventListener('change', () => {
                // 切换前缀时更新按钮状态
                const searchInput = document.getElementById('searchInput');
                const searchBtn = document.getElementById('searchBtn');
                this.updateSearchBtnState(searchInput, searchBtn);
            });
        }
    }

    // 设置输入验证
    setupInputValidation() {
        const searchInput = document.getElementById('searchInput');
        const searchTypeRadios = document.querySelectorAll('input[name="searchType"]');
        
        if (searchInput) {
            // 初始设置（默认是车次查询）
            this.applyTrainNumberInputRestriction(searchInput);
            
            // 监听输入事件
            searchInput.addEventListener('input', (e) => {
                const currentType = document.querySelector('input[name="searchType"]:checked')?.value || 'trainCode';
                if (currentType === 'trainCode') {
                    this.handleTrainNumberInput(e);
                }
                this.updateSearchBtnState(searchInput, document.getElementById('searchBtn'));
            });
        }

        // 监听查询类型切换
        if (searchTypeRadios.length > 0) {
            searchTypeRadios.forEach(radio => {
                radio.addEventListener('change', (e) => {
                    const newType = e.target.value;
                    this.handleSearchTypeChange(newType, searchInput);
                    this.toggleRoutesOptionVisibility(newType);
                });
            });
        }
    }

    // 处理车次查询的输入限制 - 只允许数字
    handleTrainNumberInput(e) {
        let value = e.target.value;
        
        // 只保留数字
        let numbersOnly = value.replace(/[^0-9]/g, '');
        
        // 不能以0开头
        if (numbersOnly.startsWith('0')) {
            numbersOnly = numbersOnly.replace(/^0+/, '');
            if (numbersOnly === '') numbersOnly = '';
        }
        
        // 限制最大长度为4位（支持4位数字车次）
        if (numbersOnly.length > 4) {
            numbersOnly = numbersOnly.substring(0, 4);
        }
        
        e.target.value = numbersOnly;
    }

    // 处理查询类型切换
    handleSearchTypeChange(newType, searchInput) {
        const trainSelect = document.getElementById('TrainSelect');
        
        if (newType === 'trainCode') {
            // 切换到车次查询：显示TrainSelect，应用数字限制
            if (trainSelect) {
                trainSelect.style.display = 'block';
            }
            this.applyTrainNumberInputRestriction(searchInput);
            
            // 清除可能存在的字母前缀，只保留数字
            if (searchInput) {
                let currentValue = searchInput.value;
                // 去掉字母部分，只保留数字
                searchInput.value = currentValue.replace(/[^0-9]/g, '');
            }
        } else {
            // 切换到车号查询：隐藏TrainSelect，移除限制
            if (trainSelect) {
                trainSelect.style.display = 'none';
            }
            this.removeInputRestriction(searchInput);
        }
        
        this.updateSearchBtnState(searchInput, document.getElementById('searchBtn'));
    }

    // 应用车次查询输入限制（只允许数字）
    applyTrainNumberInputRestriction(input) {
        input.setAttribute('inputmode', 'numeric');
        input.setAttribute('pattern', '[0-9]*');
        input.setAttribute('maxlength', '4');
        input.setAttribute('placeholder', '输入4位车次数字...');
    }

    // 移除输入限制
    removeInputRestriction(input) {
        input.removeAttribute('inputmode');
        input.removeAttribute('pattern');
        input.removeAttribute('maxlength');
        input.setAttribute('placeholder', '输入车号...');
    }

    // 切换交路选项的显示状态
    toggleRoutesOptionVisibility(searchType) {
        const showRoutesCheckbox = document.getElementById('showRoutes');
        const showRoutesLabel = document.querySelector('label[for="showRoutes"]');
        const routeOptionContainer = document.querySelector('.route-option');
        const trainSelect = document.getElementById('TrainSelect');

        if (searchType === 'trainId') {
            // 车号查询：显示交路选项，隐藏TrainSelect
            if (trainSelect) {
                trainSelect.style.display = 'none';
            }
            showRoutesCheckbox.disabled = false;
            showRoutesLabel.style.opacity = '1';
            if (routeOptionContainer) {
                routeOptionContainer.style.display = 'block';
            }
        } else {
            // 车次查询：隐藏或禁用交路选项，显示TrainSelect
            if (trainSelect) {
                trainSelect.style.display = 'block';
            }
            showRoutesCheckbox.disabled = true;
            showRoutesLabel.style.opacity = '0.5';
            if (routeOptionContainer) {
                routeOptionContainer.style.display = 'block';
            }
        }
    }

    // 更新搜索按钮状态
    updateSearchBtnState(input, btn) {
        if (input && btn) {
            const searchType = document.querySelector('input[name="searchType"]:checked')?.value || 'trainCode';
            
            if (searchType === 'trainCode') {
                // 车次查询：需要同时有前缀选择和数字输入
                const trainSelect = document.getElementById('TrainSelect');
                const hasPrefix = trainSelect && trainSelect.value;
                const hasNumbers = input.value.trim().length > 0;
                
                if (hasPrefix && hasNumbers) {
                    btn.classList.add('active');
                    btn.disabled = false;
                } else {
                    btn.classList.remove('active');
                    btn.disabled = true;
                }
            } else {
                // 车号查询：只需要有输入内容
                if (input.value.trim()) {
                    btn.classList.add('active');
                    btn.disabled = false;
                } else {
                    btn.classList.remove('active');
                    btn.disabled = true;
                }
            }
        }
    }

    // 处理搜索逻辑
    async handleSearch() {
        const searchInput = document.getElementById('searchInput');
        const searchBtn = document.getElementById('searchBtn');
        let keyword = searchInput?.value.trim();

        if (!keyword) return;

        // 获取查询类型
        const searchType = document.querySelector('input[name="searchType"]:checked')?.value || 'trainCode';
        
        if (searchType === 'trainCode') {
            // 获取前缀
            const trainSelect = document.getElementById('TrainSelect');
            const prefix = trainSelect ? trainSelect.value : 'G';
            
            // 组合成完整车次：前缀 + 数字
            keyword = prefix + keyword;
            
            // 验证格式：G/D/C开头，后面跟1-4位数字，不能以0开头
            if (!/^[GCD][1-9]\d{0,3}$/.test(keyword)) {
                const resultContainer = document.getElementById('resultContainer');
                if (resultContainer) {
                    resultContainer.innerHTML = '<p>车次查询格式：请选择G/D/C前缀并输入1-4位有效数字（不能以0开头）</p>';
                    resultContainer.classList.remove('empty');
                }
                return;
            }
        }

        const now = Date.now() / 1000;
        if (now - this.lastQueryTime < this.cooldownSeconds) {
            this.startCooldown();
            return;
        }

        this.setSearchState('查询中...', true);

        const resultContainer = document.getElementById('resultContainer');
        if (resultContainer) {
            resultContainer.innerHTML = '<p>正在查询中，请稍候...</p>';
            resultContainer.classList.remove('empty');
        }

        const showRoutesCheckbox = document.getElementById('showRoutes');
        const showRoutes = (searchType === 'trainId' && showRoutesCheckbox?.checked) || false;

        const iconSettings = window.settingsManager ? 
            window.settingsManager.getIconDisplaySettings() : 
            { showTrainIcons: true, showBureauIcons: true };

        try {
            const data = await this.mockSearchAPI(keyword, searchType, showRoutes, iconSettings);
            
            if (data.success) {
                this.renderResults(data, resultContainer);
                this.lastQueryTime = Date.now() / 1000;
                this.startCooldown();
            } else {
                resultContainer.innerHTML = `<p>${data.message || '查询失败'}</p>`;
            }
        } catch (error) {
            resultContainer.innerHTML = `<p>查询出错: ${error.message}</p>`;
        } finally {
            this.setSearchState('查询', false);
        }
    }

    // 后端查询接口
    async mockSearchAPI(keyword, searchType, showRoutes, iconSettings) {
        try {
            const params = new URLSearchParams({
                keyword: keyword.trim(),
                type: searchType === 'trainCode' ? 'trainCode' : 'trainNumber',
                show_routes: showRoutes ? 'true' : 'false',
                show_train_icons: iconSettings.showTrainIcons ? 'true' : 'false',
                show_bureau_icons: iconSettings.showBureauIcons ? 'true' : 'false'
            });

            const response = await fetch(`/search_train?${params.toString()}`, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();

            if (!data.success) {
                return {
                    success: false,
                    message: data.message || '查询失败'
                };
            }

            return {
                success: true,
                results: data.results,
                count: data.count || data.results.length,
                iconSettings: iconSettings
            };
        } catch (error) {
            console.error('搜索请求失败:', error);
            return {
                success: false,
                message: `网络错误：${error.message}`
            };
        }
    }

    // 渲染结果
    renderResults(data, container) {
        if (!container) return;

        container.classList.remove('empty');
        container.innerHTML = '';

        const iconSettings = data.iconSettings || { 
            showTrainIcons: true, 
            showBureauIcons: true 
        };

        if (data.results && data.results.length > 0) {
            const countDiv = document.createElement('div');
            countDiv.className = 'result-count';
            countDiv.innerHTML = `共找到${data.count || data.results.length}条结果`;
            container.appendChild(countDiv);

            data.results.forEach((result) => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'result-item';

                const trainModel = result.train;
                const trainNumber = result.number;
                const bureau = result.bureau;
                const depot = result.depot;
                const manufacturer = result.manufacturer;
                const remark = result.remark;
                const queryTime = result.query_time;
                const trainIcon =  result.model_icon_url;
                const bureauIcon = result.bureau_icon_url;
                const route = result.route;

                itemDiv.innerHTML = `
                    <h3>
                        ${trainIcon}
                        ${trainModel}-${trainNumber}
                        ${bureauIcon}
                    </h3>
                    <p><strong>配属路局:</strong> ${bureau}</p>
                    <p><strong>配属动车所:</strong> ${depot}</p>
                    <p><strong>生产厂家:</strong> ${manufacturer}</p>
                    ${remark ? `<p><strong>备注:</strong> ${remark}</p>` : ''}
                    ${queryTime ? `<p><strong>查询时间:</strong> ${queryTime}</p>` : ''}
                    ${route}
                `;

                container.appendChild(itemDiv);
            });
        } else {
            container.innerHTML = '<p>未找到匹配结果</p>';
        }
    }

    // 冷却功能
    startCooldown() {
        let remainingSeconds = this.cooldownSeconds;

        const searchBtn = document.getElementById('searchBtn');
        if (!searchBtn) return;

        searchBtn.classList.add('cooldown');
        searchBtn.disabled = true;
        searchBtn.textContent = `冷却中(${remainingSeconds}s)`;

        if (this.cooldownInterval) clearInterval(this.cooldownInterval);

        this.cooldownInterval = setInterval(() => {
            remainingSeconds--;
            if (remainingSeconds <= 0) {
                clearInterval(this.cooldownInterval);
                this.endCooldown();
            } else {
                searchBtn.textContent = `冷却中(${remainingSeconds}s)`;
            }
        }, 1000);
    }

    endCooldown() {
        const searchBtn = document.getElementById('searchBtn');
        const searchInput = document.getElementById('searchInput');
        
        if (searchBtn) {
            searchBtn.classList.remove('cooldown');
            searchBtn.textContent = '查询';
            if (searchInput) {
                this.updateSearchBtnState(searchInput, searchBtn);
            }
        }
    }

    setSearchState(text, disabled) {
        const searchBtn = document.getElementById('searchBtn');
        if (searchBtn) {
            searchBtn.textContent = text;
            searchBtn.disabled = disabled;
            if (disabled) {
                searchBtn.classList.remove('active');
            }
        }
    }

    // Tab 导航
    setupTabNavigation() {
        document.querySelectorAll('.tab-item').forEach(tab => {
            tab.addEventListener('click', function () {
                const page = this.getAttribute('data-page');
                
                document.querySelectorAll('.page').forEach(p => {
                    p.classList.remove('active');
                });
                
                const targetPage = document.getElementById(`${page}-page`);
                if (targetPage) {
                    targetPage.classList.add('active');
                }
                
                document.querySelectorAll('.tab-item').forEach(t => {
                    t.classList.remove('active');
                });
                this.classList.add('active');
            });
        });

        // 初始化高亮首页
        document.querySelectorAll('.tab-item').forEach(tab => {
            if (tab.getAttribute('data-page') === 'index') {
                tab.classList.add('active');
            } else {
                tab.classList.remove('active');
            }
        });
    }

    // 只做最基本的初始化
    applyMinimalSettings() {
        const settings = JSON.parse(localStorage.getItem('emuAioSettings')) || {};
        if (settings.autoFocusSearch !== false) {
            const searchInput = document.getElementById('searchInput');
            if (searchInput) {
                setTimeout(() => searchInput.focus(), 100);
            }
        }
    }
}


// 页面加载完成后初始化应用
document.addEventListener('DOMContentLoaded', function() {
    // 创建全局主题管理器
    window.themeManager = new ThemeManager();
    
    // 创建设置管理器（全局可用，必须在主应用之前创建）
    window.settingsManager = new SettingsManager();
    
    // 创建主应用（如果当前是首页）
    if (document.getElementById('index-page')) {
        window.mainApp = new MainApp();
    }
    
    // 自动聚焦搜索框（如果设置开启）
    const settings = JSON.parse(localStorage.getItem('emuAioSettings')) || {};
    if (settings.autoFocusSearch) {
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            setTimeout(() => searchInput.focus(), 100);
        }
    }
});
