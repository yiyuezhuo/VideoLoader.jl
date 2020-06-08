
function to_clip(frame_list) # we may replace this with more genric transform function
    batch = cat(channelview.(frame_list)..., dims=4) # CHWD
    batch = permuteddimsview(batch, [3,2,4,1])  # CHWD -> WHDC
    batch .|> Float32
end

struct CenterCrop
    height::Int
    width::Int
end

function (center_crop::CenterCrop)(img)
    height, width = size(img)
    if (width < center_crop.width) | (height < center_crop.height)
        @warn "imgage size $(size(img)) is too small to get center crop, a resize is called to cover"
        sz = (max(height, center_crop.height), max(width, center_crop.width))
        img = imresize(img, sz)
    end
    height, width = size(img)
        
    w_offset = floor(Int, (width - center_crop.width) / 2) + 1
    h_offset = floor(Int, (height - center_crop.height) / 2) + 1
    
    img[h_offset:(h_offset+center_crop.height-1), w_offset:(w_offset+center_crop.width-1)]
end

struct RandomCropVideo
    height::Int
    width::Int
end

function (random_crop_video::RandomCropVideo)(frame_list)
    frame = frame_list[1]
    height, width = size(frame)
    if (height < random_crop_video.height) | (width < random_crop_video.width)
        sz = (max(height, random_crop_video.height), max(width, random_crop_video.width))
        frame_list = [imresize(frame, sz) for frame in frame_list]
    end
    
    offset_height = ceil(Int, rand()*(height - random_crop_video.height))
    offset_width = ceil(Int, rand()*(width - random_crop_video.width))
    
    [frame[offset_height : offset_height + random_crop_video.height - 1,
           offset_width : offset_width + random_crop_video.width - 1] for frame in frame_list]
end

