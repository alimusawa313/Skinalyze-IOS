// Safari share preprocessing: read the product title and ingredient text from the page the user is already viewing.
// Runs in the page; nothing is fetched or sent anywhere.
var ProductPage = function () {};

ProductPage.prototype = {
    run: function (args) {
        var title = (document.querySelector('meta[property="og:title"]') || {}).content || document.title || "";
        var ingredients = "";
        var scripts = document.querySelectorAll('script[type="application/ld+json"]');
        for (var i = 0; i < scripts.length; i++) {
            var text = scripts[i].textContent || "";
            var match = text.match(/"ingredients?"\s*:\s*"([^"]{10,4000})"/i);
            if (match) { ingredients = match[1]; break; }
        }
        if (!ingredients && document.body) {
            var body = document.body.innerText || "";
            var index = body.toLowerCase().indexOf("ingredients");
            if (index >= 0) { ingredients = body.substr(index, 2500); }
        }
        args.completionFunction({ title: title.substr(0, 200), ingredients: ingredients });
    },
    finalize: function (args) {}
};

var ExtensionPreprocessingJS = new ProductPage();
