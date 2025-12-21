# -*- coding: utf-8 -*-
from flask import Flask, render_template, jsonify, request, url_for
import sqlite3
import requests
import json
import time
import re
import os

requests.packages.urllib3.disable_warnings()

Last_change_time = 2512212125

port=5555
cool_time = 3

# ==================================================
# Flask初始化
# ==================================================
app = Flask(
    __name__,
    template_folder='assets',
    static_folder='assets'
)

# ==================================================
# 铁路局图标 Base64 数据加载（从 icon.json）
# ==================================================
BUREAU_ICONS_BASE64 = {}

def load_bureau_icons():
    global BUREAU_ICONS_BASE64
    with open('assets/icon.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
        BUREAU_ICONS_BASE64 = data.get('bureau_icons', {})
    return True

# 启动时自动加载
load_bureau_icons()

# ==================================================
# 辅助函数
# ==================================================
def map_multiple_keys(keys, value):
    return dict.fromkeys(keys, value)

# ==================================================
# 列车模型标准化规则 (China-emu.cn 使用)
# ==================================================
CRH6A_B_NUMBER_RANGES = [(656, 666), (675, 682)]
CRH6A_C_NUMBER_LIST = [
    '0644', '0645', '0646', '0647', '0648',
    '0652', '0653', '0654', '0655'
]

TRAIN_MODEL_NORMALIZATION_MAP = {
    'CR450AF': 'CR450AFs',
    'CR450BF': 'CR450BFs',

    **map_multiple_keys(['CR400AF-A', 'CR400AF-B'], 'CR400AF'),
    **map_multiple_keys(
        ['CR400AF-AE', 'CR400AF-S', 'CR400AF-AS',
         'CR400AF-AZ', 'CR400AF-BS', 'CR400AF-BZ', 'CR400AF-Z', 'CR400AF-C'],
        'CR400AF-C'
    ),

    **map_multiple_keys(['CR400BF-A', 'CR400BF-B', 'CR400BF-C'], 'CR400BF'),
    **map_multiple_keys(['CR400BF-AS', 'CR400BF-BS', 'CR400BF-GS'], 'CR400BF-S'),
    **map_multiple_keys(['CR400BF-AZ', 'CR400BF-BZ', 'CR400BF-GZ'], 'CR400BF-Z'),

    **map_multiple_keys(['CRH380AL', 'CRH380AN'], 'CRH380A'),

    'CRH380BL': 'CRH380B',
    'CRH380CL': 'CRH380C',
    'CRH2B': 'CRH2A',
    'CRH1B': 'CRH1A',
    'CRH6A-A': 'CRH6A',
    'CRH6F': 'CRH6F',
    'CRH6F-A': 'CRH6F-A',
    'CRH3A-A': 'CRH3A-A'
}

SPECIAL_MODEL_RULES = {
    'CR400BF-J': {'0001': 'CR400BF-J', '0003': 'CR400BF-J-0003'},
    'CR400AF-J': {'0002': 'CR400AF-J', '0004': 'CR400AF-C', '0005': 'CR400AF-C'},
    'CR400BF-C': {'5162': 'CR400BF-C-5162'},
    'CR400BF-Z': {'0524': 'CR400BF-Z-0524'},
    'CR400AF-J': {'2808': 'CR400AF-J'},
    'CRH380A': {'number_ranges': [(251, 259)], 'override_model': 'CRH380M'},
    'CRH6A-A': {
        'number_ranges': [(212, 216)],
        **{f"{num:04d}": 'CRH6A-B' for start, end in CRH6A_B_NUMBER_RANGES for num in range(start, end + 1)},
        **map_multiple_keys(CRH6A_C_NUMBER_LIST, 'CRH6A-C')
    },
    'CRH2A': {'2460': 'CRH2G'},
    'CRH2E': {'number_ranges': [(2461, 2466)]},
    'CRH2G': {'number_ranges': [(2417, 2426), (4072, 4082), (4106, 4114)]}
}

@app.route('/')
def homepage():
    return render_template(
        'index.html',
        Bui='25.12.20.19.49',
        cool_time=cool_time,
        bureau_icons=BUREAU_ICONS_BASE64  # 新增：把所有图标数据传给前端
    )

# ==================================================
# 工具函数
# ==================================================
def extract_last_four_digits(text):
    if not text:
        return None
    digits = ''.join(c for c in str(text) if c.isdigit())
    return digits[-4:] if len(digits) >= 4 else None

def normalize_train_model_for_icon(raw_model, raw_number):
    if not raw_model:
        return '未知'
    normalized = TRAIN_MODEL_NORMALIZATION_MAP.get(raw_model, raw_model.split('-')[0] if '-' in raw_model else raw_model)

    if raw_model in SPECIAL_MODEL_RULES:
        rules = SPECIAL_MODEL_RULES[raw_model]
        if 'number_ranges' in rules:
            try:
                num_val = int(raw_number)
                for start, end in rules['number_ranges']:
                    if start <= num_val <= end:
                        normalized = rules.get('override_model', normalized)
            except (ValueError, TypeError):
                pass
        if raw_number in rules:
            normalized = rules[raw_number]

    return normalized

# ==================================================
# 本地数据库查询（SQLite）
# ==================================================
def search_local_db(last_four_digits: str):
    """按车组号后四位模糊查询本地 data.db"""
    if not last_four_digits:
        return []

    try:
        conn = sqlite3.connect('assets/data.db')
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()

        query = """
            SELECT tt.type_code AS model,
                   tu.train_number AS number,
                   tu.bureau,
                   tu.depot,
                   tu.manufacturer,
                   tu.remarks
            FROM train_units tu
            JOIN train_types tt ON tu.type_id = tt.id
            WHERE tu.train_number LIKE ?
            ORDER BY tu.train_number
        """
        cur.execute(query, (f'%{last_four_digits}',))
        rows = cur.fetchall()
        conn.close()

        results = []
        for row in rows:
            full_number = row['number'] or ''
            four_digits = extract_last_four_digits(full_number)
            normalized = normalize_train_model_for_icon(row['model'], four_digits)
            bureau_key = (row["bureau"] or "air").strip().replace(" ", "")
            if bureau_key in BUREAU_ICONS_BASE64:
                bureau_icon_url = BUREAU_ICONS_BASE64[bureau_key]
            else:
                # fallback 到传统文件路径（兼容旧图标或未收录的局）
                bureau_icon_url = url_for(
                    'static',
                    filename=f'static/{bureau_key}.png'
                )

            results.append({
                'train_model_raw': row['model'] or '',
                'train_number_raw': full_number,
                'display_model': row['model'] or '',
                'train_model_normalized': normalized,
                'model_icon_url': f'https://china-emu.cn/img/cute/{normalized}.png',
                'bureau': row['bureau'] or '',
                'depot': row['depot'] or '',
                'manufacturer': row['manufacturer'] or '',
                'remark': row['remarks'] or '',
                'bureau_icon_url': bureau_icon_url,
                'source_hint': '来自本地数据库'
            })
        return results

    except sqlite3.Error as e:
        app.logger.error(f"[SQLite Error] {e}")
        return []
    except Exception as e:
        app.logger.error(f"[Local DB Error] {e}")
        return []

# ==================================================
# rail.re 在线查询
# ==================================================
def fetch_rail_re(query_type: str, keyword: str):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36 Edg/135.0.0.0"
    }
    try:
        if query_type == 'train_code':
            url = f"https://api.rail.re/train/{keyword.upper()}"
        elif query_type == 'emu_number':
            digits = extract_last_four_digits(keyword)
            if not digits:
                return None
            url = f"https://api.rail.re/emu/{digits}"
        else:
            return None

        resp = requests.get(url, headers=headers, timeout=10, verify=False)
        if resp.ok:
            resp.encoding = 'utf-8'
            return resp.text
        return None
    except Exception as e:
        app.logger.error(f"[rail.re Error] {e}")
        return None

# ==================================================
# 主查询逻辑（修复版：统一参数为 show_routes，并完善 fallback）
# ==================================================
def search_train_vehicle(*, keyword: str, search_type: str, query_time: float):
    app.logger.info(f"[查询] keyword={keyword}, type={search_type}")

    # 用于保存实时交路信息（车次 + 时间）
    current_train_no = None
    route_time_str = None

    # Step 1: 获取实时 emu_no 和交路信息
    realtime_emu_no = None
    realtime_prefix = None

    if search_type == 'trainCode':
        raw = fetch_rail_re('train_code', keyword)
        if not raw or raw in ('', '[]'):
            return [], 'network', '未查询到该车次信息'
        try:
            data = json.loads(raw)
            if not data:
                return [], 'network', '该车次暂无运行记录'
            latest = data[0]
            realtime_emu_no = latest.get('emu_no', '').strip()
            if not realtime_emu_no:
                return [], 'network', '无法解析车组号'
            realtime_prefix = realtime_emu_no[:5].upper()

            current_train_no = latest.get('train_no', '').strip()
            date_part = latest.get('date', '')
            time_part = latest.get('time', '')  # 如 "20:03"
            if time_part and ':' in time_part:
                route_time_str = f"{date_part} {time_part.split()[0]}"
            else:
                route_time_str = f"{date_part} 00:00"
        except Exception as e:
            return [], 'network', f'解析失败: {e}'
    else:
        # 车号查询：检查前端传的 show_routes 参数
        show_routes = request.args.get('show_routes', 'false').lower() == 'true'
        if show_routes:
            raw = fetch_rail_re('emu_number', keyword)
            if raw and raw not in ('', '[]'):
                try:
                    data = json.loads(raw)
                    if data:
                        latest = data[0]
                        realtime_emu_no = latest.get('emu_no', '').strip()
                        if realtime_emu_no:
                            realtime_prefix = realtime_emu_no[:5].upper()
                            current_train_no = latest.get('train_no', '').strip()
                            date_part = latest.get('date', '')
                            time_part = latest.get('time', '')
                            if time_part and ':' in time_part:
                                route_time_str = f"{date_part} {time_part.split()[0]}"
                            else:
                                route_time_str = f"{date_part} 00:00"
                except Exception:
                    pass  # 忽略错误，继续本地查询

    # Step 2: 提取后四位
    last_four = extract_last_four_digits(keyword if search_type == 'trainNumber' else realtime_emu_no or keyword)
    if not last_four:
        return [], None, '车号格式错误'

    # Step 3: 本地数据库查询
    local_results = search_local_db(last_four)

    # Step 4: 车型前缀过滤逻辑（根据查询类型区别对待）
    if realtime_prefix and local_results:
        matched = [r for r in local_results if (r['train_model_raw'] or '')[:5].upper() == realtime_prefix]
        unmatched = [r for r in local_results if r not in matched]

        if search_type == 'trainCode':
            # 车次查询：强制只保留实时匹配的（准确性优先）
            if matched:
                local_results = matched
                app.logger.info(f"【车次查询】强制过滤成功: 只保留实时车型 {realtime_prefix} 的 {len(matched)} 条记录")
            else:
                # 没匹配到也清空本地，强制走在线 fallback（保证显示的是今天实际运行的那辆）
                local_results = []
                app.logger.info(f"【车次查询】本地无实时匹配车型，强制 fallback 到在线查询")
        else:
            # 车号查询 + 开启交路：仅优先排序，不删除其他
            if matched:
                local_results = matched + unmatched
                app.logger.info(f"【车号查询】实时车型匹配: 优先显示 {len(matched)} 条，补充显示 {len(unmatched)} 条")
            # 如果没匹配到，就保持原顺序（不做任何改动）

    # Step 5: 本地有结果 → 添加实时信息并返回
    if local_results:
        show_routes = request.args.get('show_routes', 'false').lower() == 'true'
        input_length = len(keyword.strip())
        if input_length > 9:
            input_prefix = ''.join(c for c in keyword.upper() if c.isalpha())[:5]  # 提取输入的前5字母
            local_results = [r for r in local_results if r['train_model_raw'][:5].upper() == input_prefix]

        query_time_str = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(query_time))
        for r in local_results:
            r['query_time'] = query_time_str

            if show_routes:
                # 分别为每辆车查询交路
                full_emu_no = r['train_number_raw']
                raw = fetch_rail_re('emu_number', full_emu_no)
                if raw and raw not in ('', '[]'):
                    try:
                        data = json.loads(raw)
                        if data:
                            latest = data[0]
                            r['current_train_no'] = latest.get('train_no', '').strip()
                            date_part = latest.get('date', '')
                            time_part = latest.get('time', '')
                            if time_part and ':' in time_part:
                                r['route_time'] = f"{date_part} {time_part.split()[0]}"
                            else:
                                r['route_time'] = f"{date_part} 00:00"
                    except Exception:
                        pass  # 忽略错误，继续下一辆
                time.sleep(0.5)  # 礼貌延迟，避免频繁请求

        local_results.sort(key=lambda x: 0 if x.get('current_train_no') else 1)

        return local_results, 'local', None

    # Step 6: 本地无结果或过滤后为空 → fallback 在线查询
    if search_type == 'trainCode' or (search_type == 'trainNumber' and request.args.get('show_routes', 'false').lower() == 'true'):
        raw = fetch_rail_re('emu_number', last_four)
        if not raw or raw in ('', '[]'):
            return [], 'network', '该车组无运行记录（或不在本地库中）'

        try:
            data = json.loads(raw)
            if not data:
                return [], 'network', '该车组暂无记录'
            latest = data[0]
            emu_no = latest.get('emu_no', '')
            if not emu_no:
                return [], 'network', '未获取到车组号'

            raw_model = emu_no.split('-')[0] if '-' in emu_no else ''.join(c for c in emu_no if not c.isdigit())
            normalized = normalize_train_model_for_icon(raw_model, last_four)

            date_part = latest.get('date', '')
            time_part = latest.get('time', '')
            route_time_display = f"{date_part} {time_part.split()[0]}" if time_part and ':' in time_part else f"{date_part} 00:00"

            result = {
                'train_model_raw': raw_model,
                'train_number_raw': emu_no,
                'display_model': raw_model,
                'train_model_normalized': normalized,
                'model_icon_url': f'https://china-emu.cn/img/cute/{normalized}.png',
                'bureau': '',
                'depot': '',
                'manufacturer': '',
                'bureau_icon_url': BUREAU_ICONS_BASE64['air'],
                'query_time': time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(query_time)),
                'route_time': route_time_display,
                'current_train_no': latest.get('train_no', '').strip()
            }
            return [result], 'network', None

        except Exception as e:
            return [], 'network', f'在线解析失败: {e}'

    return [], 'local', '本地无记录，且未启用在线交路查询'

@app.route('/search_train')
def search_train_route():
    start = time.time()
    keyword = request.args.get('keyword', '').strip()
    search_type = request.args.get('type', 'trainNumber')  # trainNumber 或 trainCode

    if not keyword:
        return jsonify({'success': False, 'message': '请输入查询关键字'})

    results, source, error = search_train_vehicle(
        keyword=keyword,
        search_type=search_type,
        query_time=start
    )

    duration = time.time() - start

    if error:
        return jsonify({'success': False, 'message': error})

    return jsonify({
        'success': True,
        'results': results,
        'count': len(results),
        'source': source,
        'query_duration': f'{duration:.1f}s'
    })

# ==================================================
# 程序入口
# ==================================================
if __name__ == '__main__':
    print("浏览器打开 http://localhost:"+str(port)+"/")
    if os.path.exists('/data/data/com.termux/files/usr/etc/termux-login.sh'):
        os.system('termux-open-url "http://127.0.0.1:5555"')
    else:
        import webbrowser
        webbrowser.open('http://127.0.0.1:5555')
    
    app.run(host='0.0.0.0', port=port)