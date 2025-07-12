function(instance, context) {
    
    let gridApi;

    const targetDiv = document.createElement("div")
    targetDiv.style.height = "100%"
    targetDiv.style.width = "100%"

    const gridOptions = {
    // Row Data: The data to be displayed.
    rowData: [
        { make: "Tesla", model: "Model Y", price: 64950, electric: true },
        { make: "Ford", model: "F-Series", price: 33850, electric: false },
        { make: "Toyota", model: "Corolla", price: 29600, electric: false },
    ],
    // Column Definitions: Defines the columns to be displayed.
    columnDefs: [
        { field: "make" },
        { field: "model" },
        { field: "price" },
        { field: "electric" }
    ]
};
	gridApi = agGrid.createGrid(targetDiv, gridOptions);
    console.log("gridApi", gridApi);
    window.ggg = gridApi;

}