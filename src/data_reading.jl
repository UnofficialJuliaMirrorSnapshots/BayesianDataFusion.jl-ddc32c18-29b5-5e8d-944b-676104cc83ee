export read_ecfp, read_sparse, read_rowcol
export read_binary_int32, filter_rare, write_binary_int32
export write_binary_matrix
export read_binary_float32
export read_sparse_float32, write_sparse_float32
export read_sparse_float64, write_sparse_float64
export read_sparse_binary_matrix, write_sparse_binary_matrix
export read_matrix_market

function read_ecfp(filename)
    i = 0
    next_fp = 1
    fp = Dict{Int32, Int32}()
    rows = Int32[]
    cols = Int32[]
    open(filename) do f
        for line in eachline(f)
            i += 1
            a = split(line, ",")
            for j = 2:length(a)
                fp_raw = parse(Int, a[j])
                local fp_id::Int32
                ## fetch fingerprint id range [1,...,max_fp]
                if haskey(fp, fp_raw)
                    fp_id = fp[fp_raw]
                else
                    fp_id      = next_fp
                    fp[fp_raw] = fp_id
                    next_fp += 1
                end
                push!(rows, i)
                push!(cols, fp_id)
            end
        end
    end
    println("Number of lines: $i")
    return rows, cols, fp
end

function read_rowcol(filename)
    rows = Int32[]
    cols = Int32[]
    open(filename) do f
        for line in eachline(f)
            a = split(line, ",")
            push!( rows, parse(Int32, a[1]) )
            push!( cols, parse(Int32, a[2]) )
        end
    end
    return rows, cols
end

function read_binary_int32(filename)
    open(filename) do f
        nrows = read(f, Int64)
        ncols = read(f, Int64)
        return read(f, Int32, (nrows, ncols))
    end
end

function read_binary_float32(filename)
    open(filename) do f
        nrows = read(f, Int64)
        ncols = read(f, Int64)
        return read(f, Float32, (nrows, ncols))
    end
end

function read_sparse_float32(filename)
  open(filename) do f
    nnz = read(f, Int64)
    rows = read(f, Int32, nnz)
    cols = read(f, Int32, nnz)
    vals = read(f, Float32, nnz)
    return rows, cols, vals
  end
end

function read_sparse(filename)
    rc = read_rowcol(filename)
    return sparse(rc[1], rc[2], 1f0)
end

function filter_rare(X::SparseMatrixCSC, nmin)
    featn = vec(sum(X, 1))
    return X[:, featn .>= nmin]
end

function write_binary_int32(filename, X::Matrix{Int32})
    write_binary_matrix(filename, X)
end

function write_binary_matrix(filename, X)
  open(filename, "w") do f
    write(f, size(X, 1))
    write(f, size(X, 2))
    write(f, X)
  end
end

function write_sparse_float32(filename, X::SparseMatrixCSC)
  I, J, V = findnz(X)
  write_sparse_float32(
    filename,
    convert(Vector{Int32}, I),
    convert(Vector{Int32}, J),
    convert(Vector{Float32}, V))
  nothing
end

function write_sparse_float32(filename, rows::Vector{Int32}, cols::Vector{Int32}, values::Vector{Float32})
  open(filename, "w") do f
    write(f, length(rows))
    write(f, rows)
    write(f, cols)
    write(f, values)
  end
  nothing
end

## writes the non-zero coordinates of X
function write_sparse_binary_matrix(filename, X::SparseMatrixCSC)
  rows, cols, V = findnz(X)
  open(filename, "w") do f
    write(f, size(X, 1))  ## nrows
    write(f, size(X, 2))  ## ncols
    write(f, nnz(X))      ## nnz
    write(f, convert(Vector{Int32}, rows))
    write(f, convert(Vector{Int32}, cols))
  end
  nothing
end

function read_sparse_binary_matrix(filename)
  open(filename) do f
    nrows = read(f, Int64)
    ncols = read(f, Int64)
    nnz   = read(f, Int64)
    rows  = read(f, Int32, nnz)
    cols  = read(f, Int32, nnz)
    return sparse(rows, cols, 1, nrows, ncols)
  end
end

function read_matrix_market(filename)
  nrows = 0
  ncols = 0
  nnz   = 0
  local rows::Vector{Int32}
  local cols::Vector{Int32}
  local vals::Vector{Float64}
  open(filename) do f
    ## reading the first line
    while !eof(f)
      ln = readline(f)
      ln[1] == '%' && continue
      arr = split(ln, [' ','\t'])
      nrows = parse(Int, arr[1])
      ncols = parse(Int, arr[2])
      nnz   = parse(Int, arr[3])
      break
    end
    rows = zeros(Int32, nnz)
    cols = zeros(Int32, nnz)
    vals = zeros(nnz)
    i = 1
    ## reading the rest
    while !eof(f)
      ln = readline(f)
      ln[1] == '%' && continue
      arr = split(ln, [' ','\t'])

      rows[i] = parse(Int32, arr[1])
      cols[i] = parse(Int32, arr[2])
      vals[i] = parse(Float64, arr[3])
      i += 1
    end
  end
  return sparse(rows, cols, vals, nrows, ncols)
end

function write_matrix_market(filename, X::DataFrame)
  nrows = maximum(X[:, 1])
  ncols = maximum(X[:, 2])
  nnz   = size(X, 1)
  ## writing the header line
  open(filename, "w") do f
    write(f, "%%MatrixMarket matrix coordinate real general\n")
    write(f, @sprintf("%d\t%d\t%d\n", nrows, ncols, nnz) )
    writedlm(f, convert(Matrix, X[:,1:3]))
  end
  nothing
end

function write_sparse_float64(filename, X)
  open(filename, "w") do f
    nz = findnz(X)
    write(f, size(X, 1))  ## nrow
    write(f, size(X, 2))  ## ncol
    write(f, length(nz[1]))  ## nnz
    write(f, convert(Vector{Int32}, nz[1])) ## row_idx
    write(f, convert(Vector{Int32}, nz[2])) ## col_idx
    write(f, convert(Vector{Float64}, nz[3])) ## values
  end
  nothing
end

function read_sparse_float64(filename)
  open(filename) do f
    nrow = read(f, Int64)
    ncol = read(f, Int64)
    nnz  = read(f, Int64)
    rows = read(f, Int32, nnz)
    cols = read(f, Int32, nnz)
    vals = read(f, Float64, nnz)
    return sparse(rows, cols, vals, nrow, ncol)
  end
end
