using CSV
using DataFrames

df = CSV.read("C:\\Users\\Simran\\OneDrive\\Desktop\\Julia\\Gender_Classification_Data.csv", DataFrame)
df = CSV.read("data.csv", DataFrame)

first(df,20)