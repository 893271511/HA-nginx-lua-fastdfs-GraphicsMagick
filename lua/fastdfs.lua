-- 写入文件
local function writefile(filename, info)
    local wfile=io.open(filename, "w") --写入文件(w覆盖)
    assert(wfile)  --打开时验证是否出错		
    wfile:write(info)  --写入传入的内容
    wfile:close()  --调用结束后记得关闭
end

-- 检测路径是否目录
local function is_dir(sPath)
    if type(sPath) ~= "string" then return false end

    local response = os.execute( "cd " .. sPath )
    if response == 0 then
        return true
    end
    return false
end

-- 检测文件是否存在
local file_exists = function(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local area = nil
local originalUri = ngx.var.uri;
local originalFile = ngx.var.file;
local index = string.find(ngx.var.uri, "([0-9]+)x([0-9]+)");  
if index then 
    originalUri = string.sub(ngx.var.uri, 0, index-2);  
    area = string.sub(ngx.var.uri, index);  
    index = string.find(area, "([.])");  
    area = string.sub(area, 0, index-1);  

    local index = string.find(originalFile, "([0-9]+)x([0-9]+)");  
    originalFile = string.sub(originalFile, 0, index-2)
end

-- check original file
if not file_exists(originalFile) then
    local fileid = string.sub(originalUri, 2);
    -- main
    local bit = require('bit')
    local fastdfs = require('restyfastdfs')
    local fdfs = fastdfs:new()
    fdfs:set_timeout(1000)
    fdfs:set_tracker_keepalive(0, 100)
    fdfs:set_storage_keepalive(0, 100)

    local tracker_list = {"10.4.27.59","10.4.27.60","10.4.27.78"}
    for NUMBER,IP in pairs(tracker_list) do
        fdfs:set_tracker(IP, 22122)
            local data = fdfs:do_download(fileid)
            if data then
               -- check image dir
                if not is_dir(ngx.var.image_dir) then
                    os.execute("mkdir -p " .. ngx.var.image_dir)
                end
                writefile(originalFile, data)
	    	ngx.log(ngx.DEBUG,"tracker connect:",IP)
                break	
            end
	    ngx.log(ngx.ERR,"tracker not connect:",IP)
	    if NUMBER == table.getn(tracker_list) then
            	ngx.exit(502)
	    end
    end
end

-- 创建缩略图
local image_sizes = {"80x80", "800x600", "40x40", "60x60", "1000x1000"};  
function table.contains(table, element)  
    for _, value in pairs(table) do  
        if value == element then
            return true  
        end  
    end  
    return false  
end 

if table.contains(image_sizes, area) then  
    local command = "gm convert " .. originalFile  .. " -thumbnail " .. area .. " -background gray -gravity center -extent " .. area .. " " .. ngx.var.file;  
    os.execute(command);  
end;

if file_exists(ngx.var.file) then
    --ngx.req.set_uri(ngx.var.uri, true);  
    ngx.exec(ngx.var.uri)
else
    ngx.exit(404)
end
