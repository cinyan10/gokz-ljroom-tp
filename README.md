# GOKZ LJ Room Teleport

This plugin allows players to teleport to a predefined "LJ room" location for each map, useful for KZ or GOKZ jump training servers.

## Installation

1. Compile `kzlj.sp` and upload the resulting `.smx` file to `addons/sourcemod/plugins/`
2. Upload  `ljroom.csv` to `addons/sourcemod/configs/ljroom.csv`
3. Open `addons/sourcemod/configs/databases.cfg`

### If you're using SQLite

Make sure your `"default"` section looks like this:

```cfg
	"driver_default"		"sqlite"
	
	"default"
	{
		"driver"			"default"
		"host"				"localhost"
		"database"			"sourcemod"
		"user"				"root"
		"pass"				""
		//"timeout"			"0"
		//"port"			"0"
	}
	
	"storage-local"
	{
		"driver"			"sqlite"
		"database"			"sourcemod-local"
	}
```

### If you're using MySQL

Make sure you have configured `"default"` database


> ⚠️ The first time someone joins the server after installing this plugin, the server might lag briefly.
 This is normal — the plugin performs bulk database writes when importing LJ room data from the CSV file.

## Credits

- Original plugin author: **Evan**
