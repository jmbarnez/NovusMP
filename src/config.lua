local status_enet, enet = pcall(require, "enet")
local status_socket, socket = pcall(require, "socket")

return {
    -- Network
    NETWORK_AVAILABLE = status_enet,
    ENET = status_enet and enet or nil,
    SOCKET_AVAILABLE = status_socket,
    SOCKET = status_socket and socket or nil,
    MY_NETWORK_ID = tostring(os.time() .. math.random(1000,9999)),
    PORT = 12345,
    SERVER_HOST = "localhost",
    CONNECT_TIMEOUT = 2.0,
    SEND_RATE = 0.03,

    -- Physics / Gameplay
    THRUST = 400,
    MAX_SPEED = 600,
    ROTATION_SPEED = 4,
    LINEAR_DAMPING = 2.5,
    
    -- Infinite Universe Config
    SECTOR_SIZE = 10000, -- The width/height of one "Sector" before coordinates wrap
    -- WORLD_WIDTH/HEIGHT removed because the world is now infinite

    -- Camera
    CAMERA_MIN_ZOOM = 0.5,
    CAMERA_MAX_ZOOM = 2.5,
    CAMERA_ZOOM_STEP = 0.1,
    CAMERA_DEFAULT_ZOOM = 1
}