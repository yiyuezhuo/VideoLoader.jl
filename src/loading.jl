
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
    #class_dict::Dict{String, Int}  # Dict("dog/1.mp4" => 1, "dog/2.mp4" => 1, ...)
    #info_dict::Dict{String, Video}  # [Video(250, 25), ...]
    path_list::Vector{String}  # ["dog/1.mp4", "dog/2.mp4", ...]
    path_to_idx::Dict{String, Int}  # Dict("dog/1.mp4" => 1, "dog/2.mp4" => 2)
    class_idx_list::Vector{Int}  # [1, 1, ...]
    info_list::Vector{Video}  # [Video(250, 25), Video(250, 25), ...]  # some 10s 25fps videos
    class_name_list::Vector{String}  # ["cat", "dog"]
    class_name_to_idx::Dict{String, Int}  # Dict("cat" => 1, "dog" => 2)
end

function FilesInfo(root::String)
    #class_dict_str = Dict{String, String}()
    #info_dict = Dict{String, Video}()
    path_list = String[]
    class_str_list = String[]

    offset = length(splitpath(root)) + 1
    idx = 1

    path_to_idx = Dict{String, Int}()

    for (root, dirs, files) in walkdir(root)
        sp = splitpath(root)[offset:end]
        if length(sp) >= 1
            sub_root = joinpath(sp...)
        else
            sub_root = "" # guard
        end
        for name in files
            path_key = joinpath(sub_root, name)
            if splitext(path_key)[end] != ".mp4"
                continue
            end
            class = splitpath(root)[end]
            path = joinpath(root, name)
            # println("root=$root, $name=name, class=$class, path=$path, path_key=$path_key")

            # class_dict_str[path_key] = class
            # info_dict[path_key] = Video(path)
            push!(path_list, path_key)
            push!(class_str_list, class)
            # push!(info_list, Video(path))

            path_to_idx[path_key] = idx
            idx += 1
        end
    end

    info_list = pmap(path_list) do path_key
        path = joinpath(root, path_key)
        Video(path)
    end

    class_name_list = class_str_list |> unique |> sort
    class_name_to_idx = Dict{String, Int}()
    for (idx, class) in enumerate(class_name_list)
        class_name_to_idx[class] = idx
    end

    class_idx_list = [class_name_to_idx[class_str] for class_str in class_str_list]

    FilesInfo(path_list, path_to_idx, class_idx_list, info_list, class_name_list, class_name_to_idx)
end

struct ClipPointer
    video_idx::Int
    frame_idx::Int
end

struct Dataset
    root::String
    frames_per_clip::Int  # "kernel size"
    step_between_clips::Int  # "stride"

    file_info::FilesInfo
    sample_size::Int
    sample_list::Vector{ClipPointer}
end

function Dataset(root::String; frames_per_clip=15, step_between_clips=1)
    file_info = FilesInfo(root)

    sample_list = ClipPointer[]
    sample_size = 0
    for (video_idx, info) in enumerate(file_info.info_list)
        s = floor(Int, (info.frames - frames_per_clip) / step_between_clips) + 1
        for i in 1:s
            push!(sample_list, ClipPointer(video_idx, 1 + (i-1)*step_between_clips))
        end
        sample_size += s
    end

    Dataset(root, frames_per_clip, step_between_clips, file_info, sample_size, sample_list)
end

"""
dataset[i] return (video_path, start_time, label_class)
"""
function Base.getindex(dat::Dataset, i)
    cp = dat.sample_list[i]
    p = dat.file_info.path_list[cp.video_idx]
    cls = dat.file_info.class_idx_list[cp.video_idx]
    info = dat.file_info.info_list[cp.video_idx]

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
    # frame_list = Array{Float32, 3}[]
    frame_list = Any[]
    for i in 1:frames_per_clip
        img = read(f)
        # push!(frame_list, Float32.(channelview(img)))
        push!(frame_list, img)
    end
    close(f)
    frame_list
end