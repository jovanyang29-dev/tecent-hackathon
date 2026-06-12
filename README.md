# tecent-hackathon

A cultural-themed game for Tencent Hackathon.

## 技术栈

- 引擎：Godot 4.x
- 语言：GDScript
- 类型：2D 固定场景点击解谜 / 叙事单机游戏
- 目标平台：PC 单机优先

## 项目结构

```text
tecent-hackathon/
  game/
    project.godot
    scenes/
      Main.tscn
      rooms/
        RoomBase.tscn
        Room2008.tscn
        Room2012.tscn
        Room2015.tscn
      ui/
        DialogBox.tscn
        ItemPopup.tscn
        InventoryBar.tscn
    scripts/
      GameState.gd
      RoomManager.gd
      InteractionManager.gd
      DialogueManager.gd
      SaveManager.gd
      RoomBase.gd
      ui/
        DialogBox.gd
        ItemPopup.gd
        InventoryBar.gd
    data/
      rooms/
      dialogues/
    assets/
      art/
      audio/
      fonts/
  plan/
```

## 第一周原型目标

完成房间 1 灰盒原型，跑通完整交互链：

1. 点击物品
2. 弹出信息或对话
3. 获得一个物品
4. 使用物品触发另一个对象
5. 推进剧情状态

## 打开方式

用 Godot 4.x 打开 `game/project.godot`。
