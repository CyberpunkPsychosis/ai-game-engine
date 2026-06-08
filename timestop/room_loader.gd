extends RefCounted
class_name RoomLoader
## 读 res://scenes/<id>.json → Dictionary。房间数据格式(色块版, 兼容 composer 的 world/markers):
##   world{width,height} · groundY · solids[[x,y,w,h]...] · spawn{x,y}
##   doors{name:{x,y}} · exits[{x,y,w,h,to,entry}] · benches[{x,y}] · enemies[{kind,x,y}]
## composer 以后只需补一层 solids(或把 tile 实例标 solid), markers→spawn/enemy/exit 即可对接。

static func load_data(room_id: String) -> Dictionary:
	var path := "res://scenes/%s.json" % room_id
	if not FileAccess.file_exists(path):
		push_error("[RoomLoader] 缺房间文件: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[RoomLoader] JSON 解析失败: " + path)
		return {}
	return parsed
