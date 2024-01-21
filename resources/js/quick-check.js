import "../css/main.css";
import { MDCList } from "@material/list";
import { MDCDrawer } from "@material/drawer";
const drawer = MDCDrawer.attachTo(
  document.querySelector < HTMLElement > ".mdc-drawer"
);
const list = MDCList.attachTo(
  document.querySelector < HTMLElement > ".mdc-deprecated-list"
);
list.wrapFocus = true;
