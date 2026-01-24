let a=0;function r(e,t=0){clearTimeout(a),a=setTimeout(e,t)}function c(e){const t=document.createElement("textarea");return t.innerHTML=e.replace(/&/gmi,"&amp;"),e=t.value.replace(/&amp;/gmi,"&").replace(/&lt;/gmi,"<").replace(/&gt;/gmi,">").replace(/&sect;/gmi,"§").replace(/^\s+|\s+$/g,"").replace(/\r\n|\n|\r/gm,`
`),e}export{r as d,c as p};
//# sourceMappingURL=utils-RJiw7P1o.chunk.mjs.map
