import { makeStyles } from '@material-ui/core';

const useStyles = makeStyles({
  svg: {
    width: 'auto',
    height: 28,
  },
});

const LogoFull = () => {
  const classes = useStyles();

  return (
    <svg
      className={classes.svg}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 200 28"
    >
      {/* Red vertical accent bar - BA brand */}
      <rect x="0" y="0" width="6" height="28" fill="#EB2226" />
      {/* British Airways - white for dark sidebar background */}
      <text
        x="14"
        y="18"
        fill="#ffffff"
        fontSize="14"
        fontWeight="600"
        fontFamily="'Helvetica Neue', Helvetica, Arial, sans-serif"
      >
        British Airways
      </text>
      <text
        x="14"
        y="26"
        fill="rgba(255,255,255,0.75)"
        fontSize="9"
        fontFamily="'Helvetica Neue', Helvetica, Arial, sans-serif"
      >
        Developer Portal
      </text>
    </svg>
  );
};

export default LogoFull;
