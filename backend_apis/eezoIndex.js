var express = require('express');
var bodyParser = require('body-parser');
var app = express();
var http = require('http');
var https = require('https'); 
var fs = require('fs');
var path = require('path');

var options = {  
    key: fs.readFileSync('/etc/httpd/conf.d/ssl/private_key.pem', 'utf8'),  
    cert: fs.readFileSync('/etc/httpd/conf.d/ssl/certificate_file.crt', 'utf8')  
}; 

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended:false}));

app.use(function (req, res, next) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
    next();
});

app.get('/', function(req, res) {  
    res.send("Hello");  
});

var contractFunction = require('./contractFunction');

    app.use('/contractFunction',contractFunction);

var httpServer = http.createServer(app).listen(8073,() => {  
    console.log(">> Server Is Running On Port 8073");  
});  
var secureServer = https.createServer(options, app).listen(8071,() => {  
    console.log(">> Server Is Running On Port 8071");  
});  