# Income-Based Date Recommendations System

## Overview

The Umrahly system now includes an intelligent date recommendation feature that suggests the most suitable departure dates for users based on their monthly income. This system analyzes package prices and schedules to provide personalized affordability recommendations.

## How It Works

### 1. Income Analysis
- The system retrieves the user's monthly income from their profile
- Calculates the affordability ratio: `package_price / monthly_income`
- Assigns affordability levels and scores based on this ratio

### 2. Affordability Levels

| Level | Ratio | Score | Description |
|-------|-------|-------|-------------|
| Very Affordable | ≤30% | 100 | Excellent choice, very comfortable |
| Highly Affordable | ≤50% | 90 | Great choice, easily manageable |
| Affordable | ≤80% | 80 | Good choice, well within budget |
| Manageable | ≤100% | 70 | Doable with some planning |
| Challenging | ≤150% | 50 | Requires careful budgeting |
| Difficult | ≤200% | 30 | May need additional savings |
| Very Difficult | >200% | 10 | Consider saving more first |

### 3. Recommendation Criteria

A schedule is marked as "Recommended" if:
- Affordability ratio ≤ 100% (price ≤ monthly income)
- Available quota > 5 spots
- Schedule status is "active"

### 4. Smart Ranking

Schedules are automatically ranked by:
1. **Affordability Score** (higher is better)
2. **Quota Availability** (more spots = better)
3. **Departure Date** (earlier dates prioritized)

## User Experience

### For Users with Income Information
- **Personalized Recommendations Section**: Shows top 3 recommended dates prominently
- **Affordability Indicators**: Color-coded badges showing affordability level
- **Smart Scoring**: 100-point scale for easy comparison
- **Income Context**: Shows percentage of monthly income for each option

### For Users Without Income Information
- **Profile Completion Prompt**: Encourages users to add income information
- **Standard Display**: Shows all schedules without ranking
- **Clear Call-to-Action**: Direct link to profile completion

## Technical Implementation

### Backend Functions

```elixir
# Main ranking function
rank_schedules_by_affordability(schedules, current_user)

# Price calculation (base + override)
calculate_schedule_price(schedule)

# Affordability scoring
calculate_affordability_score(affordability_ratio)

# Recommendation logic
is_schedule_recommended?(affordability_ratio, schedule)
```

### Data Flow

1. **Mount**: Retrieve package and user data
2. **Analysis**: Calculate affordability metrics for each schedule
3. **Ranking**: Sort schedules by affordability score
4. **Rendering**: Display with visual indicators and recommendations

### Performance Considerations

- All calculations done in memory during mount
- No additional database queries
- Efficient sorting and filtering
- Responsive UI with immediate feedback

## Benefits

### For Users
- **Smart Decision Making**: See which dates fit their budget
- **Time Savings**: No need to manually compare prices
- **Confidence**: Clear understanding of financial impact
- **Personalization**: Tailored to individual financial situation

### For Business
- **Higher Conversion**: Users more likely to book affordable options
- **Better User Experience**: Personalized recommendations increase satisfaction
- **Reduced Support**: Fewer questions about affordability
- **Data Insights**: Understanding of user financial preferences

## Future Enhancements

### Planned Features
- **Payment Plan Recommendations**: Suggest installment options
- **Seasonal Pricing Analysis**: Show best value seasons
- **Group Discount Suggestions**: Family/group booking recommendations
- **Savings Calculator**: How much to save monthly for specific dates

### Advanced Analytics
- **User Behavior Tracking**: Which recommendations lead to bookings
- **Price Sensitivity Analysis**: Optimal pricing strategies
- **Demand Forecasting**: Predict popular dates based on affordability

## Configuration

### Affordability Thresholds
The system can be easily configured by modifying the scoring thresholds in:
```elixir
defp calculate_affordability_score(affordability_ratio) do
  # Adjust these values as needed
  cond do
    affordability_ratio <= 0.3 -> 100
    affordability_ratio <= 0.5 -> 90
    # ... etc
  end
end
```

### Recommendation Criteria
Modify the recommendation logic in:
```elixir
defp is_schedule_recommended?(affordability_ratio, schedule) do
  # Adjust criteria as needed
  affordability_ratio <= 1.0 and schedule.quota > 5
end
```

## Testing

### Test Scenarios
1. **User with High Income**: Should see many affordable options
2. **User with Low Income**: Should see limited but clear recommendations
3. **User without Income**: Should see profile completion prompt
4. **Multiple Schedules**: Should be properly ranked and displayed
5. **Price Overrides**: Should be correctly calculated in affordability

### Sample Test Data
```elixir
# Test user with RM 5000 monthly income
user = %{monthly_income: 5000}

# Test package with RM 3000 base price
package = %{price: 3000}

# Expected affordability ratio: 3000/5000 = 0.6 (60%)
# Expected level: "affordable"
# Expected score: 80
```

## Support

For technical questions or feature requests related to the income-based recommendation system, please contact the development team or create an issue in the project repository. 