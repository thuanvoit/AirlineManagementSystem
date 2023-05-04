var add_form = document.querySelector("#add_form");
if (add_form) {
  document
    .querySelector("#add_form")
    .addEventListener("submit", async function (e) {
      e.preventDefault();
      var t = window.location.pathname;
      await fetch(t, {
        body: new URLSearchParams(new FormData(e.target)).toString(),
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      });
      window.location.reload(!0);
    });
}

setTimeout(function () {
  $(".alert").alert("close");
}, 4000);

var authors = document.getElementsByClassName("made-with-love")[0];
authors.innerHTML =
  "Made with &#10084;&#65039; by Team 5, previously Team 11" +
  "<br /> Aidan, Angela, Phat, Thuan";

document.addEventListener("DOMContentLoaded", function () {
  var myButton = document.querySelector("#detailButton");
  $(myButton).tooltip({
    trigger: "hover",
  });
});


const licenseType = document.getElementById("license_type");
const customField = document.getElementById("custom_license_type_field");
customField.style.display = "none";
licenseType.addEventListener("change", () => {
  if (licenseType.value === "custom") {
    customField.style.display = "block";
  } else {
    customField.style.display = "none";
  }
});