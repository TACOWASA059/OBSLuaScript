obs = obslua
local start_time = nil -- 録画開始時間
local folder_path = "" -- 出力フォルダを保存する変数
local file_name = "" -- 出力ファイル名
local trigger_key = "" -- トリガーキーを保存する変数
local VK_F5 = 0x74 -- デフォルトの仮想キーコード
local last_trigger_time = 0 -- 最後にキーが押された時間
local cool_down = 2 -- クールタイム（秒）

local end_open_file = ""
local end_open_url = ""

local ffi = require("ffi")


-- キーの押下状態を確認
function is_key_pressed(virtual_key_code)
    local state = ffi.C.GetAsyncKeyState(virtual_key_code)
    return state ~= 0
end

-- 秒をhh:mm:ss形式に変換する
function seconds_to_hms(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local seconds = seconds % 60
    return string.format("%02d:%02d:%02d ", hours, minutes, seconds)
end

-- エクスプローラーで指定フォルダを開く関数
function open_folder_in_explorer()
    if folder_path ~= "" then
        -- エクスプローラーでフォルダを開く
        os.execute('start "" "' .. folder_path .. '"')
    else
        obs.script_log(obs.LOG_WARNING, "フォルダパスが指定されていません。")
    end
end

-- 日付をYYYY-MM-DD_hh-mm-ss形式に変換してファイル名として使用
function recording_start_time_as_filename()
    return os.date("%Y-%m-%d_%H-%M-%S") .. ".txt"
end

-- スクリプトの説明
function script_description()
    return "選択したキーを押したときに録画経過時間を指定されたフォルダに保存します。録画開始時間がファイル名として使われます。"
end

-- スクリプトのプロパティ（設定項目）を定義
function script_properties()
    local props = obs.obs_properties_create()

    -- 出力フォルダを指定するためのテキスト入力フィールドを追加
    obs.obs_properties_add_path(props, "folder_path", "出力フォルダ", obs.OBS_PATH_DIRECTORY, "", nil)

    -- エクスプローラーで開くボタンを追加
    obs.obs_properties_add_button(props, "open_folder_button", "エクスプローラーで開く", function()
        open_folder_in_explorer()
    end)

    -- トリガーキーを選択するためのドロップダウンリストを追加
    local p = obs.obs_properties_add_list(props, "trigger_key", "トリガーキー", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    -- ファンクションキー
    for i = 1, 12 do
        obs.obs_property_list_add_string(p, "F" .. tostring(i), "F" .. tostring(i))
    end
    
    -- アルファベットキー
    for i = string.byte("A"), string.byte("Z") do
        local key = string.char(i)
        obs.obs_property_list_add_string(p, key, key)
    end

    -- 数字キー
    for i = 0, 9 do
        obs.obs_property_list_add_string(p, tostring(i), tostring(i))
    end

    -- マウスボタン
    obs.obs_property_list_add_string(p, "Left Mouse Button", "LButton")
    obs.obs_property_list_add_string(p, "Right Mouse Button", "RButton")
    obs.obs_property_list_add_string(p, "Middle Mouse Button", "MButton")
    obs.obs_property_list_add_string(p, "Mouse Side Button 1", "XButton1")
    obs.obs_property_list_add_string(p, "Mouse Side Button 2", "XButton2")

    -- 矢印キー
    obs.obs_property_list_add_string(p, "Up", "Up")
    obs.obs_property_list_add_string(p, "Down", "Down")
    obs.obs_property_list_add_string(p, "Left", "Left")
    obs.obs_property_list_add_string(p, "Right", "Right")

    -- 修飾キー
    obs.obs_property_list_add_string(p, "Space", "Space")
    obs.obs_property_list_add_string(p, "Enter", "Enter")
    obs.obs_property_list_add_string(p, "Escape", "Escape")
    obs.obs_property_list_add_string(p, "Tab", "Tab")
    obs.obs_property_list_add_string(p, "Shift", "Shift")
    obs.obs_property_list_add_string(p, "Ctrl", "Ctrl")
    obs.obs_property_list_add_string(p, "Alt", "Alt")
    obs.obs_property_list_add_string(p, "CapsLock", "CapsLock")
    obs.obs_property_list_add_string(p, "Backspace", "Backspace")

    -- テンキー
    for i = 0, 9 do
        obs.obs_property_list_add_string(p, "Numpad" .. tostring(i), "Numpad" .. tostring(i))
    end
    obs.obs_property_list_add_string(p, "NumpadPlus", "NumpadPlus")
    obs.obs_property_list_add_string(p, "NumpadMinus", "NumpadMinus")
    obs.obs_property_list_add_string(p, "NumpadMultiply", "NumpadMultiply")
    obs.obs_property_list_add_string(p, "NumpadDivide", "NumpadDivide")
    obs.obs_property_list_add_string(p, "NumpadEnter", "NumpadEnter")
    obs.obs_property_list_add_string(p, "NumpadDecimal", "NumpadDecimal")

    -- その他のキー
    obs.obs_property_list_add_string(p, "Insert", "Insert")
    obs.obs_property_list_add_string(p, "Delete", "Delete")
    obs.obs_property_list_add_string(p, "Home", "Home")
    obs.obs_property_list_add_string(p, "End", "End")
    obs.obs_property_list_add_string(p, "PageUp", "PageUp")
    obs.obs_property_list_add_string(p, "PageDown", "PageDown")
    obs.obs_property_list_add_string(p, "PrintScreen", "PrintScreen")
    obs.obs_property_list_add_string(p, "ScrollLock", "ScrollLock")
    obs.obs_property_list_add_string(p, "Pause", "Pause")
    obs.obs_property_list_add_string(p, "NumLock", "NumLock")
    obs.obs_property_list_add_string(p, "ContextMenu", "ContextMenu")

    -- 終了時に開くファイルパス
    obs.obs_properties_add_path(props, "end_open_file", "録画終了時に開く実行ファイル(メディアプレイヤー)", obs.OBS_PATH_FILE, "", nil)

    -- 終了時に開くURL
    obs.obs_properties_add_text(props, "end_open_url", "録画終了時に開くURL", obs.OBS_TEXT_DEFAULT)


    return props
end

-- 設定の更新時に呼ばれる
function script_update(settings)
    folder_path = obs.obs_data_get_string(settings, "folder_path")
    trigger_key = obs.obs_data_get_string(settings, "trigger_key")

    -- 選択されたキーに基づいて仮想キーコードを設定
    -- キーマッピング
    local key_map = {
        -- ファンクションキー
        F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73, F5 = 0x74,
        F6 = 0x75, F7 = 0x76, F8 = 0x77, F9 = 0x78, F10 = 0x79,
        F11 = 0x7A, F12 = 0x7B,

        -- 矢印キー
        Up = 0x26, Down = 0x28, Left = 0x25, Right = 0x27,

        -- 修飾キー
        Space = 0x20, Enter = 0x0D, Escape = 0x1B, Tab = 0x09,
        Shift = 0x10, Ctrl = 0x11, Alt = 0x12, CapsLock = 0x14,
        Backspace = 0x08,

        -- テンキー
        Numpad0 = 0x60, Numpad1 = 0x61, Numpad2 = 0x62, Numpad3 = 0x63,
        Numpad4 = 0x64, Numpad5 = 0x65, Numpad6 = 0x66, Numpad7 = 0x67,
        Numpad8 = 0x68, Numpad9 = 0x69, NumpadPlus = 0x6B,
        NumpadMinus = 0x6D, NumpadMultiply = 0x6A, NumpadDivide = 0x6F,
        NumpadEnter = 0x0D, NumpadDecimal = 0x6E,

        -- その他のキー
        Insert = 0x2D, Delete = 0x2E, Home = 0x24, End = 0x23,
        PageUp = 0x21, PageDown = 0x22, PrintScreen = 0x2C,
        ScrollLock = 0x91, Pause = 0x13, NumLock = 0x90,
        ContextMenu = 0x5D,

        -- マウスボタン
        LButton = 0x01, RButton = 0x02, MButton = 0x04,
        XButton1 = 0x05, XButton2 = 0x06
    }

    -- アルファベットキー
    for i = string.byte("A"), string.byte("Z") do
        local key = string.char(i)
        key_map[key] = i
    end

    -- 数字キー
    for i = 0, 9 do
        key_map[tostring(i)] = 0x30 + i
    end

    VK_F5 = key_map[trigger_key] or 0x74

    end_open_file = obs.obs_data_get_string(settings, "end_open_file") or ""
    end_open_url = obs.obs_data_get_string(settings, "end_open_url") or ""
end


-- 録画が開始された時に呼ばれるコールバック
function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        start_time = os.time() -- 録画開始時刻を取得
        file_name = folder_path .. "/" .. recording_start_time_as_filename() -- 録画開始時間をファイル名として使用

        obs.script_log(obs.LOG_INFO, "ファイルへの書き込みを開始: " .. file_name)

        local file = io.open(file_name, "a")
        if file then
            file:write("start\n")
            file:close()
        else
            obs.script_log(obs.LOG_WARNING, "ファイルを作成または開けませんでした: " .. file_name)
        end

    elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        obs.script_log(obs.LOG_INFO, "ファイルへの書き込みを終了: " .. file_name)
        start_time = nil -- 録画停止時にリセット
        
        -- URLを開く
        if end_open_url ~= "" then
            os.execute('start "" "' .. end_open_url .. '"')
        end

        -- ファイルを開く
        if end_open_file ~= "" then
            local command = 'start "" "' .. end_open_file .. '"'
            if file_name ~= "" then
                command = command .. ' "' .. file_name .. '"'
            end
            command = command .. ' "' .. obs.obs_frontend_get_last_recording() .. '"'
            os.execute(command)
        end

        
    end
end

-- 録画経過時間をファイルに書き込む
function write_elapsed_time_to_file()
    if start_time == nil or file_name == "" then
        return
    end

    -- 経過時間を計算
    local current_time = os.time()
    local elapsed_time = os.difftime(current_time, start_time)
    local elapsed_text = string.format("%s\n", seconds_to_hms(elapsed_time))

    -- ファイルに書き込み
    local file = io.open(file_name, "a")
    if file then
        file:write(elapsed_text)
        file:close()
    else
        obs.script_log(obs.LOG_WARNING, "ファイルを作成または開けませんでした: " .. file_name)
    end
end

-- 毎フレームごとに呼ばれる関数
function script_tick(seconds)
    local current_time = os.time()

    -- クールタイムが経過しているか確認
    if current_time - last_trigger_time >= cool_down then
        -- 選択されたキーが押されたときに録画経過時間をファイルに書き込む
        if is_key_pressed(VK_F5) then
            if obs.obs_frontend_recording_active() then
                write_elapsed_time_to_file()
                last_trigger_time = current_time -- 最後にキーが押された時間を更新
            end
        end
    end
end

-- スクリプトが開始されたときに呼ばれる関数
function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event) -- 録画開始と停止のイベントを監視

    -- FFIの設定はここで一度だけ行う
    ffi.cdef[[
        short GetAsyncKeyState(int vKey);
    ]]
end
