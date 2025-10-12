
######## Function to interpret BMI percentile
function interpret_percentile(p)
    if p < 10
        "You are in the **lowest 10%** of BMI (much below most people)."
    elseif p < 25
        "You are in the **bottom 25%** (below average BMI)."
    elseif p < 50
        "You are **below average** BMI."
    elseif p < 75
        "You are **above average** BMI."
    elseif p < 90
        "You are in the **top 25%** of BMI (higher than most people)."
    else
        "You are in the **highest 10%** of BMI (very high compared to others)."
    end
end




####### Function to categorize BMI into index
function bmi_index(bmi)
    if bmi < 18.5
        return 1  # Underweight
    elseif bmi < 25
        return 2  # Normal
    elseif bmi < 30
        return 3  # Overweight
    elseif bmi < 35
        return 4  # Obese Class I
    else
        return 5  # Obese Class II+
    end
end



# DIVISION
# Create Age Intervals
function age_to_interval(a)
    if ismissing(a)
        return missing          #Keep missing values as missing
    elseif a < 25
        return "18–24"          #Young adults
    elseif a < 35
        return "25–34"          #Early adulthood
    elseif a < 45
        return "35–44"          #Mid adulthood
    elseif a < 55
        return "45–54"          #Mature adulthood
    else
        return "55–69"          #Late adulthood
    end
end


#########
# We're getting everything related for input files or output directory here,
# so the actual logic on the app won't need to worry about paths.
#########
function initialize_paths()
    #### NOTE 1: @__DIR__ gives the directory of starting point of the app, regardless of where the script is located,
    #### which is the project root folder (BMI-Calculator-Analysis/), because we're running the app from main.jl
    ####   
    #### NOTE 2: because this script is running in src/, but the input/ and output/ folders are one level up,
    #### we need to go up one level (..) to access them.
    #### for example: 
    #### without "..", the path would be "/Users/sara/BMI-Calculator-Analysis/src/input" which is not correct path,
    #### with "..", the path is "/Users/sara/BMI-Calculator-Analysis/input" which is the correct path.

    # Initialiying the app input and output folder and pass it to the function
    input_dir = abspath(joinpath(@__DIR__, "..", "input"))
    println("Input directory: ", input_dir)
    # getting the full path of the gender bmi pivot table
    gender_bmi_pivot_table_path = joinpath(input_dir, "gender_bmi_pivot_table.csv")
    # validating that the file is actually exist
    if !isfile(gender_bmi_pivot_table_path)
        println("Error: The file gender_bmi_pivot_table.csv does not exist in the input directory.")
        exit(1)  # Exit the program with a non-zero status to indicate an error
    end

    # getting the full path of the Unclean_Gender_Classification_Data
    unclean_gender_classification_data_path = joinpath(input_dir, "Unclean_Gender_Classification_Data.csv")
    # validating that the file is actually exist
    if !isfile(unclean_gender_classification_data_path)
        println("Error: The file unclean_gender_classification_data_path.csv does not exist in the input directory.")
        exit(1)  # Exit the program with a non-zero status to indicate an error
    end

    # Check if the "output" directory not exists, create it
    output_dir = joinpath(@__DIR__, "..", "output")
    if !isdir(output_dir)
        mkpath(output_dir)
    end

    println("""
        Gender BMI pivot table: $gender_bmi_pivot_table_path
        Unclean Gender Classification Data: $unclean_gender_classification_data_path
        Output directory: $output_dir
    """)

    return gender_bmi_pivot_table_path, unclean_gender_classification_data_path, output_dir
end