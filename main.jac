"""TaskFlow - A multi-user todo app with AI meal planning."""

cl {
    import from frontend { app as ClientApp }

    def:pub app -> any {
        return
            <ClientApp />;
    }
}

import from byllm.lib { Model }
import from uuid { uuid4 }

glob llm = Model(model_name="claude-sonnet-4-20250514");

# --- AI Types ---

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, CLOVE, BUNCH }

obj Ingredient {
    has name: str;
    has quantity: float;
    has unit: Unit;
    has cost: float;
    has carby: bool;
    has calories: float;
}

#Tess to-do
obj Recipe {
    has name: str;
    has ingredients: list[Ingredient];
    has instructions: str;
    has estimated_cost: float;
    has for_how_many: int;
}

sem Recipe.for_how_many = "Default to 1";
sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient is high in carbohydrates";
sem Ingredient.calories = "Estimated amount of calories";

"""Categorize a todo based on its title."""
def categorize(title: str) -> Category by llm();

"""Generate a shopping list of ingredients needed for a described meal."""
def generate_ingredients(meal_description: str) -> list[Ingredient] by llm();


# --- Tess User Fix ---
node User {
    has username: str;
    has password: str;

    # Callable ability to check if given username and password match this user
    def check_credentials(input_username: str, input_password: str) -> bool {
        return self.username == input_username && self.password == input_password;
    }
}

walker Auth {
    has username: str;
    has password: str;

    # Ability triggered at root entry to authenticate user
    can login with `root entry {
        # Search all User nodes for a match
        matches = [User]@root[(self.username == username) && (self.password == password)];
        if matches {
            user = matches[0];
            report {"success": true, "user": user.username};
        } else {
            report {"success": false, "error": "User not found or invalid credentials"};
        }
    }
}


# --- Data Nodes ---

node Todo {
    has id: str,
        title: str,
        completed: bool = False,
        category: str = "other";
}

node MealIngredient {
    has name: str,
        quantity: float,
        unit: str,
        cost: float,
        carby: bool,
        calories: float;
}

# --- Todo Walkers ---

walker:priv AddTodo {
    has title: str;

    can create with `root entry {
        category = str(categorize(self.title)).split(".")[-1].lower();
        new_todo = here ++> Todo(
            id=str(uuid4()),
            title=self.title,
            category=category
        );
        report {
            "id": new_todo[0].id,
            "title": new_todo[0].title,
            "completed": new_todo[0].completed,
            "category": new_todo[0].category
        };
    }
}

walker:priv ListTodos {
    has todos: list = [];

    can collect with `root entry {
        visit [-->];
    }

    can gather with Todo entry {
        self.todos.append({
            "id": here.id,
            "title": here.title,
            "completed": here.completed,
            "category": here.category
        });
    }

    can report_all with `root exit {
        report self.todos;
    }
}


walker:priv ToggleTodo {
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.completed = not here.completed;
            report {
                "id": here.id,
                "completed": here.completed
            };
        }
    }
}

walker:priv DeleteTodo {
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete with Todo entry {
        if here.id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}

# --- Meal Planner Walkers ---

walker:priv GenerateShoppingList {
    has meal_description: str;

    can generate with Root entry {
        # First clear old ingredients
        visit [-->];
        # Then generate new ones
        ingredients = generate_ingredients(self.meal_description);
        result: list = [];
        for ing in ingredients {
            ing_data = {
                "name": ing.name,
                "quantity": ing.quantity,
                "unit": str(ing.unit).split(".")[-1].lower(),
                "cost": ing.cost,
                "carby": ing.carby,
                "calories": ing.calories
            };
            here ++> MealIngredient(
                name=ing_data["name"],
                quantity=ing_data["quantity"],
                unit=ing_data["unit"],
                cost=ing_data["cost"],
                carby=ing_data["carby"],
                calories=ing_data["calories"]
            );
            result.append(ing_data);
        }
        report result;
    }

    can clear_old with MealIngredient entry {
        del here;
    }
}

walker:priv ListMealPlan {
    has ingredients: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with MealIngredient entry {
        self.ingredients.append({
            "name": here.name,
            "quantity": here.quantity,
            "unit": here.unit,
            "cost": here.cost,
            "carby": here.carby,
            "calories": here.calories
        });
    }

    can report_all with Root exit {
        report self.ingredients;
    }
}

walker:priv ClearMealPlan {
    can collect with Root entry {
        visit [-->];
    }

    can clear with MealIngredient entry {
        del here;
        report {"cleared": True};
    }
}