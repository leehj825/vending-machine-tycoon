## Summary of Changes

I have analyzed the current codebase and found that:
1.  **Truck loading logic** exists in `GameController.loadTruck`, which handles transferring items from the `Warehouse` to a `Truck`.
2.  **Truck restocking logic** exists in `SimulationEngine._processTruckRestocking`, which transfers items from a `Truck` to a `Machine` when the truck arrives at the machine's location.
3.  **UI for loading trucks** was already partially implemented in `RoutePlannerScreen` via a `_showLoadCargoDialog` method, but it might not be obvious to the user, or fully integrated.

Based on the user's request "there is no truck loading feature so that i can stock my machine with items bought from market", it seems the user might be missing the UI entry point or it's not intuitive enough.

I will enhance the `WarehouseScreen` to also allow loading trucks directly from the warehouse view, which makes sense as a "loading dock" operation. This will provide a second, very intuitive place to manage truck inventory.

I will also verify that the `RoutePlannerScreen` cargo loading button is working as expected.

### Plan:
1.  **Modify `WarehouseScreen`**:
    *   Add a section or button to "Load Truck" from the Warehouse screen.
    *   This dialog will let users select a truck, a product from the warehouse, and a quantity to transfer.

2.  **Review `RoutePlannerScreen`**:
    *   Ensure the existing "Load Cargo" button is visible and functional.

Let's start by modifying `WarehouseScreen.dart` to add the truck loading functionality.
