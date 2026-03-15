/* www/katex-init.js */
document.addEventListener("DOMContentLoaded", function(){
  renderMathInElement(document.body, {
    delimiters: [{left: "$", right: "$", display: false}]
  });
});