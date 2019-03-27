var express= require('express');
var app = express.Router();
var Web3 = require('web3');
var EthereumTx = require('ethereumjs-tx');
var contractData = require('./ContractData.js');

web3 = new Web3(new Web3.providers.HttpProvider('https://ropsten.infura.io/bZU9r1nGjPDFbrV8L6O8'));

var EEZOTokenInstance = new web3.eth.Contract(contractData.EEZOTokenAbi, contractData.EEZOTokenAddress);

    async function getRawTransaction(_address, _gasPrice, _gasLimit, _to, _value, _data){
      var rawData = {
          nonce: web3.utils.toHex(_address),
          gasPrice: (_gasPrice != "" && typeof _gasPrice != "undefined") ? web3.utils.toHex(_gasPrice) : '0x4e3b29200',
          gasLimit: (_gasLimit != "" && typeof _gasLimit != "undefined") ? web3.utils.toHex(_gasLimit) : '0x3d090',
          to: _to,
          value: (_value != "" && typeof _value != "undefined") ? web3.utils.toHex(web3.utils.toWei(_value,"ether")) : '0x00',
          data: (_data != "" && typeof _data != "undefined") ? _data : ''
      }
      return rawData;
    }

    app.post('/transferToken', function(request,response){
      if(request.body.to == "" || request.body.to == null || typeof request.body.to == "undefined"){
        response.status(400).json({"res_code":"-7","res_message":"To Is Invalid","data":request.body.to});
      } else if(request.body.tokens_transfer == "" || request.body.tokens_transfer == null || typeof request.body.tokens_transfer == "undefined"){
        response.status(400).json({"res_code":"-11","res_message":"Tokens transfer Is Invalid","data":request.body.tokens_transfer});
      } else {
        try{    
            web3.eth.getTransactionCount(contractData.SystemAddress,async function(err,nonce) {
              console.log(nonce);
              var updateBalanceData = EEZOTokenInstance.methods.transfer(request.body.to,request.body.tokens_transfer).encodeABI();
              var rawTransaction = await getRawTransaction(nonce,'','',contractData.EEZOTokenAddress,'',updateBalanceData);
              var tx = new EthereumTx(rawTransaction);
              tx.sign(Buffer.from(contractData.SystemKey, 'hex'));
              var serializedTx = tx.serialize();
              web3.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'), function(error,hash) {
                if (!error){
                  console.log("Transfer Data = "+hash);
                  response.json({"res_code":"0","res_message":"Tokens Transfer Successfully","data":hash});
                }
                else{
                  console.log("Transfer error = "+error);
                  response.status(400).json({"res_code":"-1","res_message":"Error While Transferring EEZOToken","data":""});
                }
              });
            });

        } catch(error){
          console.log(error);
          response.json({"res_code":"-9","res_message":"Something Went Wrong!","data":""});
        }
      }
    });

    app.post('/ether/transferFund', function(request,response){
      if(request.body.to == "" || request.body.to == null || typeof request.body.to == "undefined"){
        response.status(400).json({"res_code":"-5","res_message":"To Is Invalid","data":request.body.to});
      } else if(request.body.ether_transfer == "" || request.body.ether_transfer == null || typeof request.body.ether_transfer == "undefined"){
        response.status(400).json({"res_code":"-7","res_message":"Ether Transfer Is Invalid","data":request.body.ether_transfer});
      } else {
        try{
            web3.eth.getTransactionCount(contractData.SystemAddress,async function(err,nonce) {                           
              console.log(nonce);
              var rawTransaction = await getRawTransaction(nonce,'','',request.body.to,(request.body.ether_transfer).toString(),'');
              var tx = new EthereumTx(rawTransaction);
              tx.sign(Buffer.from(contractData.SystemKey, 'hex'));
              var serializedTx = tx.serialize();
              web3.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'), function(error,hash) {
                if (!error){
                  console.log("Ether Transfer Data = "+hash);
                  response.json({"res_code":"0","res_message":"Ether Transfer Successfully","data":hash});
                }
                else{
                  console.log("Ether Transfer error = "+error);
                  if(error.toString() === "Error: insufficient funds for gas * price + value"){
                    response.json({"res_code":"-1","res_message":"Error While Transferring Ether - Insufficient funds in account","data":""});    
                  } else {
                    response.json({"res_code":"-1","res_message":"Error While Transferring Ether","data":""});
                  }
                }
              });
            });
        } catch(error){
          console.log(error);
          response.json({"res_code":"-9","res_message":"Something Went Wrong!","data":""});
        }
      }
    });

    app.post('/botPurchase', function(request,response){
      // if(request.connection.remoteAddress !== "::ffff:127.0.0.1"){
      //   response.status(401).json({"error":"Unauthorized access"}); 
      // } else {
        if(request.body.ether_transfer == "" || request.body.ether_transfer == null || typeof request.body.ether_transfer == "undefined"){
          response.status(400).json({"res_code":"-11","res_message":"Ether transfer Is Invalid","data":request.body.ether_transfer});
        } else if(request.body.ether_transfer == 0 || request.body.ether_transfer == "0"){
          response.status(400).json({"res_code":"-7","res_message":"Ether Transfer Is Invalid - 0","data":request.body.ether_transfer});
        } else {
          try{
              web3.eth.getTransactionCount(contractData.SystemAddress,async function(err,nonce) {
                console.log(nonce);
                var botPurchaseData = EEZOTokenInstance.methods.botPurchase().encodeABI();                  
                var rawTransaction = await getRawTransaction(nonce,'',700000,contractData.EEZOTokenAddress,request.body.ether_transfer,botPurchaseData);
                var tx = new EthereumTx(rawTransaction);
                tx.sign(Buffer.from(contractData.SystemKey, 'hex'));
                var serializedTx = tx.serialize();
                web3.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'), function(error,hash) {
                  if (!error){
                    console.log("Bot Ether Transfer Data = "+hash);
                    response.json({"res_code":"0","res_message":"Tokens Transfer Successfully","data":hash});
                  }
                  else{
                    console.log("Bot Ether Transfer error = "+error);
                    response.status(400).json({"res_code":"-1","res_message":"Error While Transferring EEZOToken","data":""});
                  }
                });
              });
          } catch(error){
            console.log(error);
            response.json({"res_code":"-9","res_message":"Something Went Wrong!","data":""});
          }
        }
      // }
    });

    app.post('/generateInvoice', function(request,response){
      // if(request.connection.remoteAddress !== "::ffff:127.0.0.1"){
      //   response.status(401).json({"error":"Unauthorized access"}); 
      // } else {
        if(request.body.invoice_amount == "" || request.body.invoice_amount == null || typeof request.body.invoice_amount == "undefined"){
          response.status(400).json({"res_code":"-11","res_message":"Invoice Amount Is Invalid","data":request.body.invoice_amount});
        } else {
          try{
              web3.eth.getTransactionCount(contractData.SystemAddress,async function(err,nonce) {
                console.log(nonce);
                var generateInvoiceData = EEZOTokenInstance.methods.generateInvoice(web3.utils.toWei(request.body.invoice_amount,"ether")).encodeABI();                  
                var rawTransaction = await getRawTransaction(nonce,'',700000,contractData.EEZOTokenAddress,'',generateInvoiceData);
                var tx = new EthereumTx(rawTransaction);
                tx.sign(Buffer.from(contractData.SystemKey, 'hex'));
                var serializedTx = tx.serialize();
                web3.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'), function(error,hash) {
                  if (!error){
                    console.log("Generate Invoice Data = "+hash);
                    response.json({"res_code":"0","res_message":"Invoice Generated Successfully","data":hash});
                  }
                  else{
                    console.log("Generate Invoice error = "+error);
                    response.status(400).json({"res_code":"-1","res_message":"Error While Generating Invoice","data":""});
                  }
                });
              });
          } catch(error){
            console.log(error);
            response.json({"res_code":"-9","res_message":"Something Went Wrong!","data":""});
          }
        }
      // }
    });

    app.post('/updateCurrencyPrice', function(request,response){
      // if(request.connection.remoteAddress !== "::ffff:127.0.0.1"){
      //   response.status(401 ).json({"error":"Unauthorized access"}); 
      // } else {
        if(request.body.ether_price == "" || request.body.ether_price == null || typeof request.body.ether_price == "undefined"){
          response.status(400).json({"res_code":"-11","res_message":"Ether Price Is Invalid","data":request.body.ether_price});
        } else {
          try{
              web3.eth.getTransactionCount(contractData.OwnerAddress,async function(err,nonce) {
                console.log(nonce);
                var setCurrencyData = EEZOTokenInstance.methods.setCurrencyPriceUSD(0,web3.utils.toWei((request.body.ether_price).toString(),"ether")).encodeABI();                  
                var rawTransaction = await getRawTransaction(nonce,1000000000,'',contractData.EEZOTokenAddress,'',setCurrencyData);
                var tx = new EthereumTx(rawTransaction);
                tx.sign(Buffer.from(contractData.OwnerKey, 'hex'));
                var serializedTx = tx.serialize();
                web3.eth.sendSignedTransaction('0x' + serializedTx.toString('hex'), function(error,hash) {
                  if (!error){
                    console.log("Update Currency Price Data = "+hash);
                    response.json({"res_code":"0","res_message":"Currency Price Updated Successfully","data":hash});
                  }
                  else{
                    console.log("Update Currency Price error = "+error);
                    response.status(400).json({"res_code":"-1","res_message":"Error While Updating Currency Price","data":""});
                  }
                });
              });
          } catch(error){
            console.log(error);
            response.json({"res_code":"-9","res_message":"Something Went Wrong!","data":""});
          }
        }
      // }
    });

module.exports = app;