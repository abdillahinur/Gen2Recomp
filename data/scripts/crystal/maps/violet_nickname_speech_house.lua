local StaticMap = require("data.scripts.crystal.StaticMap")

return StaticMap.define({
  id = "crystal.maps.violet_nickname_speech_house",
  prefix = "crystal.violet_nickname_house",
  mapId = "10:9",
  path = "maps/VioletNicknameSpeechHouse.asm",
  labels = {
    "VioletNicknameSpeechHouse_MapScripts",
    "VioletNicknameSpeechHouseTeacherScript",
    "VioletNicknameSpeechHouseLassScript",
    "VioletNicknameSpeechHouseBirdScript",
  },
  notes = "Used for all nickname-house interactions.",
  objects = {
    "crystal.text.violet_nickname_house.teacher",
    "crystal.text.violet_nickname_house.lass",
    "crystal.text.violet_nickname_house.bird",
  },
})
