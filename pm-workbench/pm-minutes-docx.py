# -*- coding: utf-8 -*-
"""把钉钉 AI 听记 +detail 的 JSON 生成规范化 Word 会议纪要。

用法: python pm-minutes-docx.py --json <detail.json> --out <输出.docx>
输入 JSON: { "title": str, "uuid": str, "detail": {basic/summary/keywords/transcript/todos...} }
"""
import argparse
import json
import sys

from docx import Document
from docx.shared import Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH


def add_heading(doc, text, level=1):
    h = doc.add_heading(text, level=level)
    for run in h.runs:
        run.font.color.rgb = None
    return h


def para(doc, text, bold=False, size=None):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.bold = bold
    if size:
        run.font.size = Pt(size)
    return p


def get(d, *keys, default=None):
    cur = d
    for k in keys:
        if not isinstance(cur, dict):
            return default
        cur = cur.get(k)
        if cur is None:
            return default
    return cur


def unwrap(node):
    """dws +detail 的每项产物形如 {dingOpenErrcode, errorMsg, result, success}；
    真实数据在 result 内（嵌套层级随接口版本可能不同，这里做兼容解包）。"""
    if isinstance(node, dict) and 'result' in node and isinstance(node.get('result'), dict):
        inner = node.get('result')
        # 保留成功标记，便于正文中标注失败项
        inner = dict(inner)
        inner.setdefault('__success', node.get('success'))
        inner.setdefault('__error', node.get('errorMsg') if node.get('success') is False else None)
        return inner
    return node if isinstance(node, dict) else {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()

    with open(args.json, 'r', encoding='utf-8-sig') as f:
        payload = json.load(f)
    detail = payload.get('detail') or {}
    basic = unwrap(detail.get('basic') or detail.get('basicInfo') or {})
    summary_node = unwrap(detail.get('summary') or {})
    todos_node = unwrap(detail.get('todos') or {})
    keywords_node = unwrap(detail.get('keywords') or {})
    transcript_node = unwrap(detail.get('transcript') or {})
    title = payload.get('title') or basic.get('title') or '未命名会议'

    doc = Document()
    doc.add_heading(title, level=0)

    info_rows = []
    for key, label in (('startTime', '开始时间'), ('endTime', '结束时间'), ('duration', '时长(毫秒)'), ('durationMillis', '时长(毫秒)'), ('url', '分享链接')):
        v = basic.get(key)
        if v not in (None, ''):
            info_rows.append(f'{label}: {v}')
    if payload.get('uuid'):
        info_rows.append(f"taskUuid: {payload['uuid']}")
    if info_rows:
        add_heading(doc, '基本信息', level=1)
        for row in info_rows:
            para(doc, row)

    summary = summary_node
    summary_text = ''
    if isinstance(summary, dict):
        summary_text = summary.get('fullSummary') or summary.get('summary') or ''
    elif isinstance(summary, str):
        summary_text = summary
    add_heading(doc, 'AI 摘要', level=1)
    if summary_text:
        for block in str(summary_text).split('\n'):
            if block.strip():
                para(doc, block.rstrip())
    else:
        para(doc, '（无摘要）')

    todos = todos_node
    items = None
    if isinstance(todos, dict):
        # dws: {actions:[...], dingtalkTodoList:[{title, executorList, ...}]}
        actions = todos.get('actions') or []
        todo_list = todos.get('dingtalkTodoList') or []
        items = []
        for a in actions:
            if isinstance(a, dict):
                items.append({'content': a.get('value') or a.get('content') or '', 'assignee': '', 'dueDate': ''})
            else:
                items.append({'content': str(a), 'assignee': '', 'dueDate': ''})
        for t in todo_list:
            names = []
            for e in (t.get('executorList') or []):
                names.append(e.get('name') or e.get('nickName') or e.get('unionId') or '')
            items.append({'content': t.get('title') or '', 'assignee': '、'.join([n for n in names if n]), 'dueDate': t.get('dueDate') or ''})
        if not items:
            items = todos.get('items') or todos.get('todos')
    elif isinstance(todos, list):
        items = todos
    add_heading(doc, '行动项', level=1)
    if items:
        for it in items:
            if isinstance(it, dict):
                line = '- ' + str(it.get('content') or it.get('text') or '')
                extra = []
                if it.get('assignee'):
                    extra.append('负责人: %s' % it['assignee'])
                else:
                    extra.append('负责人: 未指定')
                if it.get('dueDate'):
                    extra.append('截止: %s' % it['dueDate'])
                else:
                    extra.append('截止: 未指定')
                line += '（' + '；'.join(extra) + '）'
                para(doc, line)
            else:
                para(doc, '- %s（负责人: 未指定；截止: 未指定）' % it)
    else:
        para(doc, '（未提取到行动项）')

    keywords = keywords_node
    kw_list = None
    if isinstance(keywords, dict):
        kw_list = keywords.get('keywords') or keywords.get('items')
    elif isinstance(keywords, list):
        kw_list = keywords
    add_heading(doc, '关键词', level=1)
    if kw_list:
        words = []
        for k in kw_list:
            words.append(k.get('keyword') or k.get('word') if isinstance(k, dict) else str(k))
        para(doc, ' · '.join([w for w in words if w]))

    transcript = transcript_node
    paras = None
    if isinstance(transcript, dict):
        paras = transcript.get('paragraphList') or transcript.get('paragraphs') or transcript.get('items')
    elif isinstance(transcript, list):
        paras = transcript
    add_heading(doc, '转写全文', level=1)
    if paras:
        for p in paras:
            if isinstance(p, dict):
                speaker = p.get('nickName') or p.get('speakerName') or p.get('speaker') or '发言人'
                text = p.get('paragraph') or p.get('text') or p.get('content') or ''
                if text:
                    para(doc, f'{speaker}: {text}')
            else:
                para(doc, str(p))
    else:
        para(doc, '（无转写内容）')

    doc.save(args.out)
    print('OK', args.out)


if __name__ == '__main__':
    main()
