# -*- coding: utf-8 -*-
from flask import Flask, render_template, jsonify, request
import requests
import json
import time
import re
import os

requests.packages.urllib3.disable_warnings()

port = 5555

app = Flask(__name__, template_folder='assets', static_folder='assets')

# 全局变量存储 JSON 数据
TRAIN_DATA = {}
BUREAU_ICONS_BASE64 = {}

def load_config():
    """加载统一的 config.json"""
    global TRAIN_DATA, BUREAU_ICONS_BASE64
    global TRAIN_MODEL_NORMALIZATION_MAP, SPECIAL_MODEL_RULES
    global CRH6A_B_NUMBER_RANGES, CRH6A_C_NUMBER_LIST

    try:
        with open('assets/config.json', 'r', encoding='utf-8') as f:
            cfg = json.load(f)

        # 修复：TRAIN_DATA 应该初始化为列表，而不是字典
        TRAIN_DATA = []  # 重新初始化为空列表
        
        # 数据平铺逻辑修复
        for model, records in cfg.get('data', {}).items():
            for r in records:
                r_copy = r.copy()
                r_copy['type_code'] = model
                TRAIN_DATA.append(r_copy)  # 现在可以对列表使用 append

        BUREAU_ICONS_BASE64 = cfg.get('icons', {})
        CRH6A_B_NUMBER_RANGES = cfg.get('CRH6A_B_NUMBER_RANGES', [])
        CRH6A_C_NUMBER_LIST = cfg.get('CRH6A_C_NUMBER_LIST', [])
        TRAIN_MODEL_NORMALIZATION_MAP = cfg.get('TRAIN_MODEL_NORMALIZATION_MAP', {})
        SPECIAL_MODEL_RULES = cfg.get('SPECIAL_MODEL_RULES', {})

        print(f"加载 config.json 完成，共 {len(TRAIN_DATA)} 条列车记录")
    except Exception as e:
        print(f"加载 config.json 失败: {e}")
        # 确保 TRAIN_DATA 在异常情况下也是有效列表
        TRAIN_DATA = []

# 启动时加载
load_config()

@app.route('/')
def homepage():
    return render_template('index.html', bureau_icons=BUREAU_ICONS_BASE64)

def extract_last_four_digits(text):
    if not text:
        return None
    digits = ''.join(c for c in str(text) if c.isdigit())
    return digits[-4:] if len(digits) >= 4 else None
    
def normalize_train_model_for_icon(raw_model, raw_number):
    if not raw_model:
        return '未知'
    normalized = TRAIN_MODEL_NORMALIZATION_MAP.get(raw_model, raw_model.split('-')[0] if '-' in raw_model else raw_model)
    rules = SPECIAL_MODEL_RULES.get(raw_model, {})
    if 'number_ranges' in rules:
        try:
            num_val = int(raw_number)
            for start, end in rules['number_ranges']:
                if start <= num_val <= end:
                    normalized = rules.get('override_model', normalized)
        except:
            pass
    # 精确匹配
    if raw_number in rules:
        normalized = rules[raw_number]
    # B/C 特殊映射
    if raw_model == 'CRH6A-A':
        if raw_number in rules.get('B_RANGE_MAPPING', {}):
            normalized = rules['B_RANGE_MAPPING'][raw_number]
        elif raw_number in rules.get('C_LIST_MAPPING', {}):
            normalized = rules['C_LIST_MAPPING'][raw_number]
    return normalized
    
def search_local_json(last_four_digits, show_train_icons, show_bureau_icons, emutime, emuno, show_routes):
    if not last_four_digits or not TRAIN_DATA:
        return []
    results = []
    for record in TRAIN_DATA:
        train_number = record.get('车组号') or record.get('train_number') or ''
        four_digits = extract_last_four_digits(train_number)
        if four_digits == last_four_digits:
            model = record.get('type_code') or record.get('model') or ''
            normalized = normalize_train_model_for_icon(model, four_digits)
            bureau = record.get('配属路局') or record.get('bureau') or ''
            depot = record.get('配属动车所') or record.get('depot') or ''
            manufacturer = record.get('生产厂家') or record.get('manufacturer') or ''
            remarks = record.get('备注') or record.get('remarks') or ''
            model_icon_url = f'<img src="https://china-emu.cn/img/cute/{normalized}.png" style="width:32px;height:32px;">' if show_train_icons else ''
            bureau_icon_url = f'<img src="{BUREAU_ICONS_BASE64.get(bureau.strip().replace(" ", ""), "")}" style="width:32px;height:32px;">' if show_bureau_icons else ''
            route = f'<p><strong>交路时间:</strong>{emutime}</p><p><strong>本务车次:</strong>{emuno}</p>' if show_routes else ''
            results.append({
                'number': train_number,
                'train': model,
                'model_icon_url': model_icon_url,
                'bureau_icon_url': bureau_icon_url,
                'bureau': bureau,
                'depot': depot,
                'manufacturer': manufacturer,
                'remark': remarks,
                'route': route
            })
    return results
    
def fetch_rail_re(query_type: str, keyword: str):
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        if query_type == 'train_code':
            url = f"https://api.rail.re/train/{keyword.upper()}"
        elif query_type == 'emu_number':
            if not keyword:
                return None
            if any(c.isalpha() for c in keyword):
                emu = keyword.replace('-', '').upper()
                url = f"https://api.rail.re/emu/{emu}"
            else:
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
    except Exception:
        return None

def search_train_vehicle(*, keyword: str, search_type: str, query_time: float,
                         show_train_icons: str, show_bureau_icons: str, show_routes: str):
    """主要搜索逻辑"""
    # --- 统一布尔处理 ---
    show_routes = show_routes if isinstance(show_routes, bool) else str(show_routes).lower() == 'true'
    show_train_icons = show_train_icons if isinstance(show_train_icons, bool) else str(show_train_icons).lower() == 'true'
    show_bureau_icons = show_bureau_icons if isinstance(show_bureau_icons, bool) else str(show_bureau_icons).lower() == 'true'

    current_train_no = None
    realtime_emu_no = None
    realtime_prefix = None
    date_part = current_train_no = date_part = ''
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
        except Exception as e:
            return [], 'network', f'解析失败: {e}'

    last_four = extract_last_four_digits(keyword if search_type == 'trainNumber' else realtime_emu_no)
    if not last_four:
        return [], None, '车号格式错误'

    local_results = search_local_json(last_four, show_train_icons, show_bureau_icons, date_part, current_train_no, show_routes)

    # 实时交路信息获取
    if local_results and show_routes:
        query_time_str = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(query_time))
        for r in local_results:
            r['query_time'] = query_time_str
            r['current_train_no'] = ''
            r['date_part'] = ''
            r['route'] = ''
            model = (r.get('train') or '').upper().replace('-', '')
            number = extract_last_four_digits(r.get('number')) or ''
            full_emu_no = f"{model}{number}"

            raw = fetch_rail_re('emu_number', full_emu_no)
            if raw and raw not in ('', '[]'):
                try:
                    data = json.loads(raw)
                    matched = None
                    for item in data:
                        emu_no_api = item.get('emu_no', '').upper().replace('-', '')
                        if emu_no_api == full_emu_no:
                            matched = item
                            break
                    if not matched:
                        for item in data:
                            if number in item.get('emu_no', ''):
                                matched = item
                                break
                    if matched:
                        r['current_train_no'] = matched.get('train_no', '').strip()
                        r['date_part'] = str(matched.get('date', '') or '')
                        r['route'] = (f'<p><strong>交路时间:</strong>{r["date_part"]}</p>'f'<p><strong>本务车次:</strong>{r["current_train_no"]}</p>')
                except Exception:
                    r['route'] = '<p><strong>交路时间:</strong>解析失败</p><p><strong>本务车次:</strong>解析失败</p>'

    return local_results, 'local', None if local_results else '未找到匹配的车组信息'

@app.route('/search_train')
def search_train_route():
    start = time.time()
    keyword = request.args.get('keyword', '').strip()
    search_type = request.args.get('type', 'trainNumber')
    show_routes = request.args.get('show_routes', '')
    show_train_icons = request.args.get('show_train_icons', '')
    show_bureau_icons = request.args.get('show_bureau_icons', '')

    if not keyword:
        return jsonify({'success': False, 'message': '请输入查询关键字'})

    results, source, error = search_train_vehicle(
        keyword=keyword,
        search_type=search_type,
        query_time=start,
        show_routes=show_routes,
        show_train_icons=show_train_icons,
        show_bureau_icons=show_bureau_icons
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

@app.route('/reload_data')
def reload_data():
    try:
        load_config()
        return jsonify({'success': True, 'message': f'配置重载成功，共 {len(TRAIN_DATA)} 条记录'})
    except Exception as e:
        return jsonify({'success': False, 'message': f'重载失败: {e}'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port, debug=True)