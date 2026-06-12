extends PanelContainer

var speaker_label: Label
var text_label: Label


func _ready() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	speaker_label = Label.new()
	speaker_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	vbox.add_child(speaker_label)

	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_label)


func show_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker if speaker != "" else ""
	text_label.text = text
	show()


func hide_dialogue() -> void:
	hide()
	speaker_label.text = ""
	text_label.text = ""
