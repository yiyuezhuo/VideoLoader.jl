
"""
Simple struct collecting interested info
"""
struct Video
    frames::Int
    fps::Int
end

function Video(s::VideoIO.StreamInfo)
    frame_rate = s.stream.avg_frame_rate
    @assert frame_rate.den == 1
    Video(s.stream.nb_frames, frame_rate.num)
end

function Video(avi::VideoIO.AVInput)
    Video(avi.video_info[1])
end

function Video(path::String)
    f = VideoIO.open(path)
    v = Video(f)
    close(f)
    v
end

struct FilesInfo
    root::String
    path_list::Vector{String}  # ["dog/1.mp4", "dog/2.mp4", ...]
    path_to_idx::Dict{String, Int}  # Dict("dog/1.mp4" => 1, "dog/2.mp4" => 2)
    class_idx_list::Vector{Int}  # [1, 1, ...]
    info_list::Vector{Video}  # [Video(250, 25), Video(250, 25), ...]  # some 10s 25fps videos
    class_name_list::Vector{String}  # ["cat", "dog"]
    class_name_to_idx::Dict{String, Int}  # Dict("cat" => 1, "dog" => 2)
end

function FilesInfo(root::String, path_list::Vector{String}, class_idx_list::Vector{Int}, 
                  class_name_list::Vector{String})
    path_to_idx = Dict{String, Int}()

    for (idx, path_key) in enumerate(path_list)
        path_to_idx[path_key] = idx
    end

    info_list = pmap(path_list) do path_key
        path = joinpath(root, path_key)
        Video(path)
    end

    class_name_to_idx = Dict{String, Int}()
    for (idx, class) in enumerate(class_name_list)
        class_name_to_idx[class] = idx
    end

    FilesInfo(root, path_list, path_to_idx, class_idx_list, info_list, 
              class_name_list, class_name_to_idx)
end    

function FilesInfo(root::String)
    path_list = String[]
    class_str_list = String[]

    offset = length(splitpath(root)) + 1

    for (root, dirs, files) in walkdir(root)
        sp = splitpath(root)[offset:end]
        if length(sp) >= 1
            sub_root = joinpath(sp...)
        else
            sub_root = "" # sentinel
        end
        for name in files
            path_key = joinpath(sub_root, name)
            if splitext(path_key)[end] != ".mp4"
                continue
            end
            class = splitpath(root)[end]
            path = joinpath(root, name)

            push!(path_list, path_key)
            push!(class_str_list, class)
        end
    end

    class_name_list = class_str_list |> unique |> sort
    class_name_to_idx = Dict{String, Int}()
    for (idx, class) in enumerate(class_name_list)
        class_name_to_idx[class] = idx
    end

    class_idx_list = [class_name_to_idx[class_str] for class_str in class_str_list]
    
    FilesInfo(root, path_list, class_idx_list, class_name_list)
end

function FilesInfo(root::String, json_index_path::String; offset=1)
    # offset = 1 represent convert base0 to base1
    json_dat = JSON.parsefile(json_index_path)
    class_name_list = Vector{String}(json_dat["classes"])
    path_list = String[]
    class_idx_list = Int[]
    for (path_key, class_base_0) in json_dat["samples"]
        push!(path_list, path_key)
        push!(class_idx_list, class_base_0 + offset)
    end
    FilesInfo(root, path_list, class_idx_list, class_name_list)
end

struct ClipPointer
    video_idx::Int
    frame_idx::Int
end

struct Dataset
    root::String
    frames_per_clip::Int  # "kernel size"
    step_between_clips::Int  # "stride"

    files_info::FilesInfo
    sample_size::Int
    sample_list::Vector{ClipPointer}
end

function Dataset(files_info::FilesInfo; frames_per_clip=15, step_between_clips=1)
    root = files_info.root

    sample_list = ClipPointer[]
    sample_size = 0
    for (video_idx, info) in enumerate(files_info.info_list)
        s = floor(Int, (info.frames - frames_per_clip) / step_between_clips) + 1
        for i in 1:s
            push!(sample_list, ClipPointer(video_idx, 1 + (i-1)*step_between_clips))
        end
        sample_size += s
    end

    Dataset(root, frames_per_clip, step_between_clips, files_info, sample_size, sample_list)
end

function Dataset(root::String; kw...)
    files_info = FilesInfo(root)
    Dataset(files_info; kw...)
end

function Dataset(root::String, json_index_path::String; kw...)
    files_info = FilesInfo(root, json_index_path)
    Dataset(files_info; kw...)
end

"""
dataset[i] return (video_path, start_time, label_class)
"""
function Base.getindex(dat::Dataset, i)
    cp = dat.sample_list[i]
    p = dat.files_info.path_list[cp.video_idx]
    cls = dat.files_info.class_idx_list[cp.video_idx]
    info = dat.files_info.info_list[cp.video_idx]

    path = joinpath(dat.root, p)
    t = 1. / info.fps * (cp.frame_idx-1)
    
    return path, t, cls
end

function Base.length(dat::Dataset)
    return dat.sample_size
end

function load_frame_list(path, t, frames_per_clip)
    io = VideoIO.open(path)
    stream = io.video_info[1].stream
    f = VideoIO.openvideo(io)
    seek(f, t)

    img = read(f)
    frame_list = [copy(img)]
    for i in 1:(frames_per_clip-1)
        read!(f, img)
        push!(frame_list, copy(img))
    end
    close(f)
    frame_list
end