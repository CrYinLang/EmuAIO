const App = (() => {
    const mainContent = document.querySelector('.main-content');
    const QUERY_INTERVAL = parseInt(mainContent?.dataset.queryInterval) || 6;
    let lastQueryTime = 0;
    let cooldownInterval = null;

    const $ = selector => document.querySelector(selector);
    const $$ = selector => Array.from(document.querySelectorAll(selector));

    function updateSearchBtnState(input, btn) {
        const hasText = !!input.value.trim();
        btn.classList.toggle('active', hasText);
        btn.disabled = !hasText;
    }

    function setSearchState(text, disabled) {
        $$('.search-btn').forEach(btn => {
            btn.textContent = text;
            btn.disabled = disabled;
        });
    }

    function startCooldown(seconds = QUERY_INTERVAL) {
        let remaining = seconds;
        const btns = $$('.search-btn');
        btns.forEach(btn => {
            btn.classList.add('cooldown');
            btn.disabled = true;
            btn.textContent = `冷却中(${remaining}s)`;
        });
        if (cooldownInterval) clearInterval(cooldownInterval);
        cooldownInterval = setInterval(() => {
            remaining--;
            if (remaining <= 0) {
                clearInterval(cooldownInterval);
                cooldownInterval = null;
                endCooldown();
            } else {
                btns.forEach(btn => (btn.textContent = `冷却中(${remaining}s)`));
            }
        }, 1000);
    }

    function endCooldown() {
        $$('.search-btn').forEach(btn => {
            btn.classList.remove('cooldown');
            btn.textContent = '查询';
        });
        $$('.search-box').forEach(input => {
            const btn = input.nextElementSibling;
            if (btn) updateSearchBtnState(input, btn);
        });
    }

    async function handleSearch(keyword, searchType, resultContainerId) {
        const now = Date.now() / 1000;
        if (now - lastQueryTime < QUERY_INTERVAL) {
            startCooldown();
            return;
        }
        if (!keyword) return;
        setSearchState('查询中...', true);
        const container = document.getElementById(resultContainerId);
        container.style.display = 'block';
        container.innerHTML = '<p>正在查询中，请稍候...</p>';
        const showRoutes = $('#showRoutes') ? $('#showRoutes').checked : false;

        try {
            const url = `/search_train?type=${encodeURIComponent(searchType)}&keyword=${encodeURIComponent(keyword)}&show_routes=${showRoutes}`;
            const resp = await fetch(url);
            const data = await resp.json();
            if (!data.success) {
                container.innerHTML = `<p>${data.message || '查询失败'}</p>`;
                return;
            }
            renderResults(data, container);
            lastQueryTime = Date.now() / 1000;
            startCooldown();
        } catch (err) {
            container.innerHTML = `<p>查询出错: ${err.message}</p>`;
        } finally {
            setSearchState('查询', false);
        }
    }

    function createText(tag, text = '') {
        const el = document.createElement(tag);
        if (text) el.textContent = text;
        return el;
    }

    function renderResults(data, container) {
        container.classList.remove('empty');
        container.innerHTML = '';
        const results = data.results || [];
        if (results.length === 0) {
            container.innerHTML = '<p>未找到匹配结果</p>';
            return;
        }

        const countDiv = createText('div');
        countDiv.className = 'result-count';
        countDiv.innerHTML = `共找到${data.count || results.length}条结果<br>`;
        container.appendChild(countDiv);

        results.forEach(r => {
            const item = document.createElement('div');
            item.className = 'result-item';

            const h3 = document.createElement('h3');

            if (r.model_icon_url) {
                const img = document.createElement('img');
                img.src = r.model_icon_url;
                img.style.width = '32px';
                img.style.height = '32px';
                img.style.verticalAlign = 'middle';
                h3.appendChild(img);
            }

            const titleText = document.createTextNode(` ${r.display_model || r.train_model_raw || ''}-${r.train_number_raw || ''}`);
            h3.appendChild(titleText);

            if (r.bureau_icon_url) {
                const img2 = document.createElement('img');
                img2.src = r.bureau_icon_url;
                img2.style.width = '32px';
                img2.style.height = '32px';
                img2.style.verticalAlign = 'middle';
                img2.style.marginLeft = '8px';
                h3.appendChild(img2);
            }

            item.appendChild(h3);

            appendKV(item, '配属路局', r.bureau);
            appendKV(item, '配属动车所', r.depot);
            appendKV(item, '生产厂家', r.manufacturer);
            if (r.remark) appendKV(item, '备注', r.remark);
            if (r.query_time) appendKV(item, '查询时间', r.query_time);
            if (r.route_time) appendKV(item, '交路时间', r.route_time);
            if (r.current_train_no) {
                const p = document.createElement('p');
                p.innerHTML = `<strong>本务车次:</strong> <span class="current-train-no"><a href="https://rail.re/#${(r.train_model_raw||'')+(r.train_number_raw||'')}" style="color: #ADD8E6; text-decoration: none; font-weight: bold;">${r.current_train_no}</a></span>`;
                item.appendChild(p);
            }

            container.appendChild(item);
        });
    }

    function appendKV(parent, k, v) {
        const p = document.createElement('p');
        const strong = document.createElement('strong');
        strong.textContent = `${k}:`;
        p.appendChild(strong);
        p.appendChild(document.createTextNode(` ${v || ''}`));
        parent.appendChild(p);
    }

    function initTabs() {
        $$('.tab-item').forEach(tab => {
            tab.addEventListener('click', function () {
                $$('.tab-item').forEach(t => t.classList.remove('active'));
                this.classList.add('active');
                $$('.content-section').forEach(s => s.classList.remove('active'));
                const id = this.getAttribute('data-tab');
                const target = document.getElementById(id + 'Section');
                if (target) target.classList.add('active');
            });
        });
    }

    function initSearchControls() {
        const trainCodeInput = $('#searchInputTrainCode');
        const trainCodeBtn = $('#searchBtnTrainCode');
        if (trainCodeInput && trainCodeBtn) {
            trainCodeInput.addEventListener('input', () => updateSearchBtnState(trainCodeInput, trainCodeBtn));
            trainCodeBtn.addEventListener('click', () => handleSearch(trainCodeInput.value.trim(), 'trainCode', 'resultContainerTrainCode'));
        }

        const trainIdInput = $('#searchInputTrainId');
        const trainIdBtn = $('#searchBtnTrainId');
        if (trainIdInput && trainIdBtn) {
            trainIdInput.addEventListener('input', () => updateSearchBtnState(trainIdInput, trainIdBtn));
            trainIdBtn.addEventListener('click', () => handleSearch(trainIdInput.value.trim(), 'trainNumber', 'resultContainer'));
        }

        $$('.search-box').forEach(input => {
            input.addEventListener('keypress', function (e) {
                if (e.key === 'Enter') {
                    const btn = this.nextElementSibling;
                    if (btn && !btn.disabled) btn.click();
                }
            });
        });
    }

    function init() {
        document.addEventListener('DOMContentLoaded', () => {
            initTabs();
            initSearchControls();
        });
    }

    return { init };
})();

App.init();