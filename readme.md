# VideoLoader

This package provides a video ML pipeline loading videos into `WHDCN` tensor using [VideoIO](https://github.com/JuliaIO/VideoIO.jl) and multi-processing. 


## Example

```julia
using VideoLoader

using VideoLoader: @setup_workers, Dataset, RandomCrop, ToClip, VideoDataLoader, Resize, RandomHorizontalFlip, Normalize, CenterCrop

workers_pid = @setup_workers(4)

root = your_video_folders
dataset_train = Dataset(root, joinpath(root, "train.json"), frames_per_clip=1)

video_data_loader = let
    
    resize = Resize(128, 171)
    random_horizontal_flip = RandomHorizontalFlip()
    center_crop = CenterCrop(112, 112)
    to_clip = ToClip()
    normalize = Normalize(Float32.([0.43216, 0.394666, 0.37645]),
                          Float32.([0.22803, 0.22145, 0.216989]))
    
    transform(x) = x |> resize |> random_horizontal_flip |> center_crop |> to_clip |> normalize
    
    batch_size = 15
    clip_per_video_epoch = 2
    video_data_loader = VideoDataLoader(dataset_train, batch_size, workers_pid, 
        clip_per_video_epoch, transform=transform)
end

for (batch_x, batch_y) in video_data_loader
    global batch_x_g = batch_x
    global batch_y_g = batch_y
    break
end

batch_y_g'
#=
1×15 LinearAlgebra.Adjoint{Int64,Array{Int64,1}}:
 2  4  3  3  2  2  2  3  3  2  3  2  4  3  4
=#

batch_x_g |> typeof, batch_x_g |> size
#=
(Array{Float32,5}, (112, 112, 1, 3, 15))
=#
-
```

## Assumed data structure

If `index` file (e.x. `train.json` in the above code example) is not specified. Following structure is assumed:

```
DATA_ROOT
    class_a
        a_1.mp4
        a_2.mp4
        ...
    class_b
        b_1.mp4
        b_2.mp4
        ...
    ...
```

Structure can be customized by `index.json` file, which will have following format:

```
{
    "classes": ["class_name_0", "class_name_1"],
    "samples": [["0_1.mp4", 0], 
                ["abc.mp4", 1],
                ["sub_d1/sub_d2/def.mp4], 0]
}
```

class index is 0-based.

Paths in `samples` are relative paths. `Root` path will be joined into the left to combine full paths. For example, if `root="my_root"`, the third sample path will be `my_root/sub_d1/sub_d2/def.mp4`.


## VideoIO Version problem

VideoIO master branch has memory leak (critical) and alignment problems (though will not occur in most cases), while the two my PR are under reviewed:

https://github.com/JuliaIO/VideoIO.jl/pull/247

https://github.com/JuliaIO/VideoIO.jl/pull/245

So you need to `dev` my fork fix [branch](https://github.com/yiyuezhuo/VideoIO.jl/tree/fix_align) to use this package temporarily.
