// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "deps/phoenix_html/web/static/js/phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".
import Tables from "./dashboard/tables"
import Charts from "./dashboard/charts"
$(document).ready(function () {
	// Cannot use jquery call syntax here to get elements. It's funny because 
	// $(document) ready is working..
	var table = document.getElementById("top-10-product-table");
	Tables.top10Table(table);

	var bar_chart = document.getElementById("top-10-product-bar-chart");
	Charts.top10ProductBarChart(bar_chart);

	var getDataButton = $("#get-data");
	getDataButton.click(function () {
		Tables.refreshDataTable();
	});
});
