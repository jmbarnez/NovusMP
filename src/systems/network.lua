local NetworkSyncSystem = require "src.network.sync_system"
local NetworkIOSystem   = require "src.network.io_system"

return {
	Sync = NetworkSyncSystem,
	IO   = NetworkIOSystem,
}