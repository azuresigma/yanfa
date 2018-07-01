var client = function(){
	//呈现引擎
	var engine = {
		ie:0,
		gecko:0,
		webkit:0,
		khtml:0,
		opera:0,
		
		//具体的版本号
		ver : null
	};
	
	//浏览器
	var browser = {
		//主要浏览器
		ie:0,
		firefox:0,
		konq:0,
		opera: 0,
		safari:0,
		uc: 0,
		baidu: 0,
		qq: 0,
		
		
		//具体的版本号
		ver: null
	};
	
	//操作系统
	var system = {
		android: false,
		ios: false,
		blackBerry: false,
		symbian: false,
		bada:false,
		windows: false,
		//具体的版本号
		ver: null
		
	};
	
	//检测操作系统
	
	//检测呈现引擎和浏览器
	var ua = navigator.userAgent.toLowerCase();   
    if (window.opera){
        engine.ver = browser.ver = window.opera.version();
        engine.opera = browser.opera = parseFloat(engine.ver);
    } else if (/applewebkit\/(\S+)/.test(ua)){
        
        //确定是Chrome 还是 Safari
        if (/chrome\/(\S+)/.test(ua)){
			browser.ver = ua.match(/chrome\/([\d.]+)/)[1];
            browser.chrome = parseFloat(browser.ver);;
        } else if (/qqbrowser\/(\S+)/.test(ua)){
			browser.ver = ua.match(/qqbrowser\/([\d.]+)/)[1];
            browser.qq = parseFloat(browser.ver);;
        } else if (/ucbrowser\/(\S+)/.test(ua)){
			browser.ver = ua.match(/ucbrowser\/([\d.]+)/)[1];
            browser.uc = parseFloat(browser.ver);;
        } else if (/baidubrowser\/(\S+)/.test(ua)){
			browser.ver = ua.match(/baidubrowser\/([\d.]+)/)[1];
            browser.baidu = parseFloat(browser.ver);
        } else if (/safari\/(\S+)/.test(ua)){
			browser.ver = ua.match(/safari\/([\d.]+)/)[1];
            browser.safari = parseFloat(browser.ver);;
        } 
		
    }
	//alert("uaflag:"+browser.baidu);	
	//alert(browser.baidu);
	//返回这些对象
	return{
		engine : engine,
		browser : browser,
		system : system
	};
};