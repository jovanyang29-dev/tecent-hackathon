extends PanelContainer

@onready var description: RichTextLabel = $MarginContainer/Description


func show_item(title: String, content: String) -> void:
	description.text = "[b]%s[/b]\n%s" % [title, content]
	show()


func close() -> void:
	hide()
