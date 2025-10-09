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