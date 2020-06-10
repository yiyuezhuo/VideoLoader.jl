"""
I must use macro, since function will raise 
    syntax: "toplevel" expression not at top level
"""
macro setup_workers(num_workers)
    quote
        workers_pid = addprocs($(num_workers))
        @everywhere workers_pid begin
            using VideoLoader
            # using VideoLoader: Video
        end
        workers_pid
    end
end

mutable struct VideoDataLoader
    dataset::Dataset
    batch_size::Int
    workers_pid::Vector{Int}
    clip_per_video_epoch::Int

    transform::Function

    next_pid_idx::Int
    indices::Vector{Int}
end

function VideoDataLoader(dataset::Dataset, batch_size::Int, workers_pid::Vector{Int},
                         clip_per_video_epoch::Int; transform=identity)
    # workers_pid = @setup_workers(num_workers)
    indices = collect(1:length(dataset))
    shuffle!(indices)
    next_pid_idx = 1
    frames_per_clip = dataset.frames_per_clip
    VideoDataLoader(dataset, batch_size, workers_pid, clip_per_video_epoch, 
        transform,
        next_pid_idx + 1, indices)
end

function make_future(loader::VideoDataLoader, path, t , frames_per_clip)
    if length(loader.workers_pid) == 0
        pid = 1  # if no worker is specified, use master process
    else
        pid = loader.workers_pid[loader.next_pid_idx]
        loader.next_pid_idx = loader.next_pid_idx % length(loader.workers_pid) + 1
    end
    @spawnat pid load_frame_list(path, t, frames_per_clip)
end

function make_future_batch(loader::VideoDataLoader, idx::Int)
    selected_length = min(length(loader.dataset)-idx, 
                          loader.batch_size, 
                          length(loader.dataset.file_info.path_list) * loader.clip_per_video_epoch - idx)
    future_list = Future[]
    cls_list = Int[]
    for i in idx:(idx+selected_length-1)
        path, t, cls = loader.dataset[loader.indices[i]]
        push!(cls_list, cls)
        future = make_future(loader, path, t, loader.dataset.frames_per_clip)
        push!(future_list, future)
    end
    idx = idx + selected_length
    return future_list, cls_list, idx
end

function collect_future_list(loader::VideoDataLoader, future_list::Vector{Future})
    cat([loader.transform(fetch(future)) for future in future_list]..., dims=5)
end

function Base.iterate(loader::VideoDataLoader)
    if length(loader.dataset) == 0
        return nothing
    end
    future_list1, cls_list1, idx1 = make_future_batch(loader, 1)
    future_list2, cls_list2, idx2 = make_future_batch(loader, idx1)
    batch1 = collect_future_list(loader, future_list1)
    return (batch1, cls_list1), (future_list2, cls_list2, idx2)
end

function Base.iterate(loader::VideoDataLoader, state::Tuple)
    future_list2, cls_list2, idx2 = state
    if length(future_list2) == 0
        return nothing
    end
    future_list3, cls_list3, idx3 = make_future_batch(loader, idx2)
    batch2 = collect_future_list(loader, future_list2)
    return (batch2, cls_list2), (future_list3, cls_list3, idx3)
end

