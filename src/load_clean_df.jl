################################################
# Here we're loading the data frame, clean it, and return the cleaned data
################################################



# Define validity checks
function is_valid(row)
    # require columns exist
    for col in (:age, :height, :weight)
        if !(col in propertynames(row)) || ismissing(row[col])
            return false
        end
    end
    age = try
        Float64(row[:age])
    catch
        return false
    end
    height = try
        Float64(row[:height])
    catch
        return false
    end
    weight = try
        Float64(row[:weight])
    catch
        return false
    end
    valid_age = 18.0 <= age <= 60.0
    valid_height = 144.0 <= height <= 210.0
    valid_weight = 34.0 <= weight <= 120.0
    return valid_age && valid_height && valid_weight
end

function load_clean_df(raw_df)
    # --- Begin user cleaning steps ---
    # Round height and weight (if present)
    if :height in names(raw_df)
        try
            raw_df.height = round.(Float64.(raw_df.height), digits=1)
        catch
            # keep as-is if conversion fails
        end
    end
    if :weight in names(raw_df)
        try
            raw_df.weight = round.(Float64.(raw_df.weight), digits=1)
        catch
        end
    end
    
    # Show invalid rows
    invalid_rows = filter(row -> !is_valid(row), eachrow(raw_df))
    println("Invalid rows:")
    println(DataFrame(invalid_rows))

    # Keep only valid rows
    clean_df = filter(is_valid, eachrow(raw_df)) |> DataFrame

    println(first(clean_df, 5))

    # Display the column names
    println("column names : $(names(clean_df))")

    # Display the number of rows and columns
    println("number of rows : $(nrow(clean_df))")
    println("number of columns : $(ncol(clean_df))")

    #Describe the dataset
    describe(clean_df)


    # Check for missing values
    ageMissing = count(ismissing, clean_df.age)
    heightMissing = count(ismissing, clean_df.height)
    println("Number of missing values in age column: $ageMissing")
    println("Number of missing values in height column: $heightMissing")


    return clean_df
end