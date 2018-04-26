$(document).ready(function() {
    function getLocation() {
        var city = document.getElementById("city");
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(showPosition);
        } else {
            city.innerHTML = "ITG";
        }
    }

    function showPosition(position) {
        var latitude = position.coords.latitude;
        var longitude = position.coords.longitude;
        var gmaps = `http://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&sensor=true`
        $.getJSON(gmaps, function(json) {
            document.querySelector("#city").text = json.results[0].address_components[3].short_name;
            console.log(json.results[0].address_components[3].short_name);
        });
    }
    // getLocation();
});
