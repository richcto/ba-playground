import { makeStyles } from '@material-ui/core';

const useStyles = makeStyles({
  svg: {
    width: 'auto',
    height: 28,
  },
});

const LogoIcon = () => {
  const classes = useStyles();

  return (
    <svg
      className={classes.svg}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 36 28"
    >
      {/* Red accent bar */}
      <rect x="0" y="0" width="36" height="4" fill="#EB2226" rx="1" />
      {/* BA monogram - white for dark sidebar */}
      <text
        x="18"
        y="20"
        fill="#ffffff"
        fontSize="16"
        fontWeight="700"
        textAnchor="middle"
        fontFamily="'Helvetica Neue', Helvetica, Arial, sans-serif"
      >
        BA
      </text>
    </svg>
  );
};

export default LogoIcon;
