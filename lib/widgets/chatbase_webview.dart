import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatbaseWebView extends StatefulWidget {
  final String agentId;

  const ChatbaseWebView({super.key, required this.agentId});

  @override
  State<ChatbaseWebView> createState() => _ChatbaseWebViewState();
}

class _ChatbaseWebViewState extends State<ChatbaseWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar if needed
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { 
              margin: 0; 
              padding: 0; 
              font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              background-color: #1a1a1a;
            }
          </style>
        </head>
        <body>
          <script>
            (function(){
              if(!window.chatbase||window.chatbase("getState")!=="initialized"){
                window.chatbase=(...arguments)=>{
                  if(!window.chatbase.q){window.chatbase.q=[]}
                  window.chatbase.q.push(arguments)
                };
                window.chatbase=new Proxy(window.chatbase,{
                  get(target,prop){
                    if(prop==="q"){return target.q}
                    return(...args)=>target(prop,...args)
                  }
                })
              }
              const onLoad=function(){
                const script=document.createElement("script");
                script.src="https://www.chatbase.co/embed.min.js";
                script.id="${widget.agentId}";
                script.domain="www.chatbase.co";
                document.body.appendChild(script)
              };
              if(document.readyState==="complete"){
                onLoad()
              }else{
                window.addEventListener("load",onLoad)
              }
            })();
          </script>
        </body>
        </html>
      ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Remove "AI Assistant" text
        backgroundColor: const Color(0xFFD2B48C), // Match beige theme
        foregroundColor: const Color(
          0xFF2D3748,
        ), // Dark text for better contrast
        elevation: 0, // Remove shadow for cleaner look
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
