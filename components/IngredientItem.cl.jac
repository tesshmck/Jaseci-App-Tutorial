"""Ingredient item component for the shopping list."""

def:pub IngredientItem(ingredient: dict) -> any {

    cost = ingredient.cost || 0;
    calories = ingredient.calories || 0;
    quantity = ingredient.quantity;
    unit = ingredient.unit;

    return
        <div className="ingredient-item">

            <div className="ingredient-info">

                <span className="ingredient-name">
                    {ingredient.name}
                </span>
                {
                    (
                        <span className="ingredient-qty">
                            {quantity} {unit}
                        </span>
                    ) if (quantity or unit) else None
                }
            </div>
            <div className="ingredient-meta">
                {
                    (
                        <span className="carb-badge">Carbs</span>
                    ) if ingredient.carby else None
                }
                <span className="cost-label">
                    ${cost.toFixed(2)}
                </span>
                <span
                    className="calorie-label"
                    title="Calories contributed by this ingredient"
                >
                    <strong>{Math.round(calories)}</strong> kcal
                </span>
            </div>
        </div>;
}
