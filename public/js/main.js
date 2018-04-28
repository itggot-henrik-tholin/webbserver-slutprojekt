$(document).ready(function() {
    function getLocation() {
        var city = document.getElementById("city");
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(showPosition);
        } else {
            city.innerHTML = "CURRENT_CITY";
        }
    }

    function showPosition(position) {
        var latitude = position.coords.latitude;
        var longitude = position.coords.longitude;
        console.log(`${latitude},${longitude}`)
        var gmaps = `http://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&sensor=true`
        $.getJSON(gmaps, function(json) {
            document.querySelector("#city").text = json.results[0].address_components[3].short_name;
            console.log(json.results[0].address_components[3].short_name);
        });
    }

    function setLocation(position) {
        var coords = position.coords;
        document.querySelector("#coords").value = `${coords.latitude},${coords.longitude}`;
    }

    // getLocation();
});

function newServerAjaxCall(url, data, code) {
    var request = new XMLHttpRequest();
    request.onreadystatechange = function() {
        if (this.readyState === 4) {
            if (this.status === 200) {
                eval(code);
            } else {
                console.log("Error appeared for server ajax call: '" + url + "'");
                console.log(this.responseText);
            }
        }
    };
    request.open("POST", url, true);
    if (data === null) {
        request.send();
    } else {
        request.send(data);
    }
}

function upvote(id) {
    id = id.split("-")
    var votes = parseInt(document.getElementById(`${id[0]}-${id[1]}`).innerHTML);
    document.getElementById(`${id[0]}-${id[1]}`).innerHTML = ++votes;
}

function downvote(id) {
    id = id.split("-")
    var votes = parseInt(document.getElementById(`${id[0]}-${id[1]}`).innerHTML);
    document.getElementById(`${id[0]}-${id[1]}`).innerHTML = --votes;
}