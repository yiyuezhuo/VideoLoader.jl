

function to_clip(frame_list::FrameList) # we may replace this with more genric transform function
    batch = cat(channelview.(frame_list)..., dims=4) # CHWD
    batch = permuteddimsview(batch, [3,2,4,1])  # CHWD -> WHDC
    batch .|> Float32
end

struct ToClip
end

function (::ToClip)(frame_list::FrameList)
    to_clip(frame_list)
end

struct CenterCrop
    height::Int
    width::Int
end

function (center_crop::CenterCrop)(frame_list::FrameList)
    height, width = size(frame_list[1])
    if (width < center_crop.width) | (height < center_crop.height)
        @warn "imgage size $(size(frame_list[1])) is too small to get center crop, a resize is called to cover"
        sz = (max(height, center_crop.height), max(width, center_crop.width))
        # img = imresize(img, sz)
        [imresize(frame, sz) for frame in frame_list]
    end
    height, width = size(frame_list[1])
        
    w_offset = floor(Int, (width - center_crop.width) / 2) + 1
    h_offset = floor(Int, (height - center_crop.height) / 2) + 1
    
    # img[h_offset:(h_offset+center_crop.height-1), w_offset:(w_offset+center_crop.width-1)]
    return [frame[h_offset:(h_offset+center_crop.height-1), 
                  w_offset:(w_offset+center_crop.width-1)] 
                    for frame in frame_list]
end


struct RandomCrop
    height::Int
    width::Int
end

function (random_crop_video::RandomCrop)(frame_list::FrameList)
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


function random_horizontal_flip(frame_list::FrameList)
    if rand() < 0.5
        return frame_list
    end

    [frame[:, size(frame,2):-1:1] for frame in frame_list]
end

struct RandomHorizontalFlip
end

function (::RandomHorizontalFlip)(frame_list::FrameList)
    random_horizontal_flip(frame_list)
end

struct Resize
    height::Int
    width::Int
end

function (t::Resize)(frame_list::FrameList)
    [imresize(frame, (t.height, t.width)) for frame in frame_list]
end

# Normalize is used after to_clip

struct Normalize{T}
    mean::Vector{T}
    std::Vector{T}
end

function (m::Normalize)(clip::VideoTensor)
    # clip: WHDC tensor
    _mean = reshape(m.mean, 1, 1, 1, length(m.mean))
    _std = reshape(m.std, 1, 1, 1, length(m.std))
    return (clip .- _mean)./ _std
end
