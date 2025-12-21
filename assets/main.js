// 全局配置
const QUERY_INTERVAL = parseInt(document.querySelector('.main-content').dataset.queryInterval) || 6;
let lastQueryTime = 0;
let cooldownInterval;

// 搜索按钮状态更新
function updateSearchBtnState(input, btn) {
    if (input.value.trim()) {
        btn.classList.add('active');
        btn.disabled = false;
    } else {
        btn.classList.remove('active');
        btn.disabled = true;
    }
}

// 冷却功能
function startCooldown() {
    let remainingSeconds = QUERY_INTERVAL;

    document.querySelectorAll('.search-btn').forEach(btn => {
        btn.classList.add('cooldown');
        btn.disabled = true;
        btn.textContent = `冷却中(${remainingSeconds}s)`;
    });

    if (cooldownInterval) clearInterval(cooldownInterval);

    cooldownInterval = setInterval(() => {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
            clearInterval(cooldownInterval);
            endCooldown();
        } else {
            document.querySelectorAll('.search-btn').forEach(btn => {
                btn.textContent = `冷却中(${remainingSeconds}s)`;
            });
        }
    }, 1000);
}

function endCooldown() {
    document.querySelectorAll('.search-btn').forEach(btn => {
        btn.classList.remove('cooldown');
        btn.textContent = '查询';
    });

    document.querySelectorAll('.search-box').forEach(input => {
        const btn = input.nextElementSibling;
        updateSearchBtnState(input, btn);
    });
}

// 查询处理
async function handleSearch(keyword, searchType, resultContainerId) {
    const now = Date.now() / 1000;

    if (now - lastQueryTime < QUERY_INTERVAL) {
        handleQueryCooldown(now);
        return;
    }

    if (!keyword) return;

    setSearchState('查询中...', true);

    const resultContainer = document.getElementById(resultContainerId);
    resultContainer.innerHTML = '<p>正在查询中，请稍候...</p>';
    resultContainer.style.display = 'block';

    const showRoutes = document.getElementById('showRoutes')
        ? document.getElementById('showRoutes').checked
        : false;

    try {
        const response = await fetch(`/search_train?type=${searchType}&keyword=${encodeURIComponent(keyword)}&show_routes=${showRoutes}`);
        const data = await response.json();

        if (!data.success) {
            resultContainer.innerHTML = `<p>${data.message || '查询失败'}</p>`;
            return;
        }

        renderResults(data, resultContainer);
        lastQueryTime = Date.now() / 1000;
        startCooldown();

    } catch (e) {
        resultContainer.innerHTML = `<p>查询出错: ${e.message}</p>`;
    } finally {
        setSearchState('查询', false);
    }
}

function handleQueryCooldown(now) {
    startCooldown();
}

function setSearchState(text, disabled) {
    document.querySelectorAll('.search-btn').forEach(btn => {
        btn.textContent = text;
        btn.disabled = disabled;
    });
}

function renderResults(data, container) {
    container.classList.remove('empty');
    container.innerHTML = '';

    if (data.results && data.results.length > 0) {
        const countDiv = document.createElement('div');
        countDiv.className = 'result-count';
        countDiv.innerHTML = `共找到${data.count || data.results.length}条结果<br>`;
        container.appendChild(countDiv);

        data.results.forEach(result => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'result-item';

            const trainModel = result.train_model_raw || result.display_model || '';
            const trainNumber = result.train_number_raw || '';
            const trainIcon = result.model_icon_url || '';
            const bureau = result.bureau || '';
            const bureauIcon = result.bureau_icon_url || '';
            const depot = result.depot || '';
            const manufacturer = result.manufacturer || '';
            const remark = result.remark || '';
            const queryTime = result.query_time || '';
            const routeTime = result.route_time || '';
            const currentTrainNo = result.current_train_no || '';  // 本务车次

            itemDiv.innerHTML = `
                <h3>
                    <img src="${trainIcon}" style="width: 32px; height: 32px; vertical-align: middle;">
                    ${trainModel}-${trainNumber}
                    <img src="${bureauIcon}" style="width:32px;height:32px; vertical-align: middle; margin-left: 8px;">
                </h3>
                <p><strong>配属路局:</strong> ${bureau}</p>
                <p><strong>配属动车所:</strong> ${depot}</p>
                <p><strong>生产厂家:</strong> ${manufacturer}</p>
                ${remark ? `<p><strong>备注:</strong> ${remark}</p>` : ''}
                ${queryTime ? `<p><strong>查询时间:</strong> ${queryTime}</p>` : ''}
                ${routeTime ? `<p><strong>交路时间:</strong> ${routeTime}</p>` : ''}
                ${currentTrainNo ? `<p><strong>本务车次:</strong> <span class="current-train-no">${currentTrainNo}</span></p>` : ''}
            `;

            container.appendChild(itemDiv);
        });
    } else {
        container.innerHTML = '<p>未找到匹配结果</p>';
    }
}
// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function () {

    // 标签栏切换
    document.querySelectorAll('.tab-item').forEach(tab => {
        tab.addEventListener('click', function () {
            document.querySelectorAll('.tab-item').forEach(t => t.classList.remove('active'));
            this.classList.add('active');

            document.querySelectorAll('.content-section').forEach(section => {
                section.classList.remove('active');
            });

            const tabId = this.getAttribute('data-tab');
            const targetSection = document.getElementById(tabId + 'Section');
            if (targetSection) {
                targetSection.classList.add('active');
            }
        });
    });

    // 车次查询
    const searchInputTrainCode = document.getElementById('searchInputTrainCode');
    const searchBtnTrainCode = document.getElementById('searchBtnTrainCode');

    if (searchInputTrainCode && searchBtnTrainCode) {
        searchInputTrainCode.addEventListener('input', () => {
            updateSearchBtnState(searchInputTrainCode, searchBtnTrainCode);
        });
        searchBtnTrainCode.addEventListener('click', () => {
            handleSearch(searchInputTrainCode.value.trim(), 'trainCode', 'resultContainerTrainCode');
        });
    }

    // 车号查询
    const searchInputTrainId = document.getElementById('searchInputTrainId');
    const searchBtnTrainId = document.getElementById('searchBtnTrainId');

    if (searchInputTrainId && searchBtnTrainId) {
        searchInputTrainId.addEventListener('input', () => {
            updateSearchBtnState(searchInputTrainId, searchBtnTrainId);
        });
        searchBtnTrainId.addEventListener('click', () => {
            handleSearch(searchInputTrainId.value.trim(), 'trainNumber', 'resultContainer');
        });
    }

    // 回车键搜索
    document.querySelectorAll('.search-box').forEach(input => {
        input.addEventListener('keypress', function (e) {
            if (e.key === 'Enter') {
                const btn = this.nextElementSibling;
                if (!btn.disabled) btn.click();
            }
        });
    });
});
