"""
将家具PNG的Alpha通道分解为碰撞矩形，实现像素级碰撞
使用网格采样 + 贪婪矩形合并，控制矩形数量在合理范围
"""
import json
from PIL import Image
import os


def grid_decompose(pixels, img_w: int, img_h: int, cell_size: int = 8, alpha_threshold: int = 64) -> list[list]:
    """
    将图片alpha通道按网格采样，生成空闲/占用格栅
    返回占用格子的坐标列表 [(gx, gy), ...]
    """
    gw = (img_w + cell_size - 1) // cell_size
    gh = (img_h + cell_size - 1) // cell_size
    
    occupied = set()
    for gy in range(gh):
        for gx in range(gw):
            x0 = gx * cell_size
            y0 = gy * cell_size
            x1 = min(x0 + cell_size, img_w)
            y1 = min(y0 + cell_size, img_h)
            opaque = 0
            total = 0
            for y in range(y0, y1):
                for x in range(x0, x1):
                    total += 1
                    if pixels[x, y][3] > alpha_threshold:
                        opaque += 1
            if total > 0 and opaque / total >= 0.3:  # 30%以上非透明 → 视为占用
                occupied.add((gx, gy))
    
    return occupied, gw, gh


def greedy_merge(occupied: set, gw: int, gh: int, cell_size: int) -> list[list]:
    """
    贪婪算法合并相邻的占用格子为大矩形
    返回 [x, y, w, h] 列表（以原始像素为单位）
    """
    unused = set(occupied)
    rects = []
    
    while unused:
        # 取最左上角的格子作为种子
        seed = min(unused, key=lambda c: (c[1], c[0]))
        gx, gy = seed
        
        # 尝试扩展矩形
        max_w = 1
        # 向右扩展
        while gx + max_w < gw and all((gx + max_w, gy + dy) in unused for dy in range(1)):
            max_w += 1
        
        max_h = 1
        # 向下扩展（要求整行都被占用）
        while gy + max_h < gh:
            can_extend = True
            for dx in range(max_w):
                if (gx + dx, gy + max_h) not in unused:
                    can_extend = False
                    break
            if can_extend:
                max_h += 1
            else:
                break
        
        # 注册矩形
        pixel_x = gx * cell_size
        pixel_y = gy * cell_size
        pixel_w = max_w * cell_size
        pixel_h = max_h * cell_size
        
        # 裁剪到图片边界
        rects.append([pixel_x, pixel_y, pixel_w, pixel_h])
        
        # 标记已使用
        for dy in range(max_h):
            for dx in range(max_w):
                unused.discard((gx + dx, gy + dy))
    
    return rects


def merge_adjacent_rects(rects: list[list], tolerance: int = 4) -> list[list]:
    """
    合并相邻的矩形（相同高度、相同x范围、垂直邻接）
    """
    if len(rects) <= 1:
        return rects
    
    merged = True
    while merged:
        merged = False
        new_rects = []
        used = [False] * len(rects)
        
        for i in range(len(rects)):
            if used[i]:
                continue
            x1, y1, w1, h1 = rects[i]
            bottom = y1 + h1
            best_j = -1
            
            for j in range(len(rects)):
                if i == j or used[j]:
                    continue
                x2, y2, w2, h2 = rects[j]
                # 垂直邻接：j在i的正下方
                if abs(y2 - bottom) <= 2 and h2 == h1:
                    # x范围相近
                    if abs(x1 - x2) <= tolerance and abs(w1 - w2) <= tolerance:
                        best_j = j
                        break
            
            if best_j >= 0:
                x2, y2, w2, h2 = rects[best_j]
                # 合并
                new_x = min(x1, x2)
                new_w = max(x1 + w1, x2 + w2) - new_x
                new_h = (y2 + h2) - y1
                new_rects.append([new_x, y1, new_w, new_h])
                used[i] = True
                used[best_j] = True
                merged = True
            else:
                new_rects.append(rects[i])
                used[i] = True
        
        rects = new_rects
    
    return rects


def convert_to_local_coords(rects: list[list], img_w: int, img_h: int) -> list[list]:
    """像素坐标 → Sprite2D 本地坐标（中心原点）"""
    cx, cy = img_w / 2.0, img_h / 2.0
    return [[x - cx, y - cy, w, h] for x, y, w, h in rects]


def process_image(path: str, cell_size: int = 16) -> dict:
    """处理单个家具图片"""
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    pixels = img.load()
    
    occupied, gw, gh = grid_decompose(pixels, w, h, cell_size)
    
    if not occupied:
        return {'image_size': [w, h], 'rect_count': 0, 'rects': []}
    
    rects = greedy_merge(occupied, gw, gh, cell_size)
    rects = merge_adjacent_rects(rects)
    local_rects = convert_to_local_coords(rects, w, h)
    
    return {
        'image_size': [w, h],
        'rect_count': len(local_rects),
        'rects': local_rects
    }


def main():
    base_dir = r'c:\Users\86130\CodeBuddy\20260605221757\tecent-hackathon\game2'
    sprites_dir = os.path.join(base_dir, 'assets', 'sprites')
    
    furniture = {
        'modern_sofa': 'modern_sofa.png',
        'modern_tvstand': 'modern_tvstand.png',
        'modern_dining_table': 'modern_dining_table.png',
        'modern_cabinet': 'modern_cabinet.png',
        'modern_plant': 'modern_plant.png',
        'modern_plant2': 'modern_plant2.png',
        'modern_shoe_rack': 'modern_shoe_rack.png',
    }
    
    # 不同物品用不同 cell_size 以平衡精度和数量
    cell_config = {
        'modern_sofa': 12,
        'modern_tvstand': 16,
        'modern_dining_table': 20,
        'modern_cabinet': 8,
        'modern_plant': 10,
        'modern_plant2': 10,
        'modern_shoe_rack': 16,
    }
    
    all_data = {}
    total_rects = 0
    
    for name, filename in furniture.items():
        path = os.path.join(sprites_dir, filename)
        if not os.path.exists(path):
            print(f'[WARN] {path} not found')
            continue
        
        cs = cell_config.get(name, 12)
        result = process_image(path, cs)
        all_data[name] = result
        total_rects += result['rect_count']
        print(f'{name}: {result["rect_count"]} rects (cell={cs}px, img={result["image_size"][0]}x{result["image_size"][1]})')
    
    output = os.path.join(base_dir, 'data', 'modern_furniture_collision.json')
    with open(output, 'w', encoding='utf-8') as f:
        json.dump(all_data, f, ensure_ascii=False)
    
    print(f'\nTotal: {total_rects} rects across {len(all_data)} items')
    print(f'Saved: {output}')


if __name__ == '__main__':
    main()
